# Agent Host Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable, configurable `nix-config.roles.agent-host` role that turns any host (desktop now, headless VPS/server later) into an always-on box running Claude Code under an isolated `agent` user, reachable over Tailscale SSH.

**Architecture:** One umbrella NixOS role composes four reusable primitives — a DE-independent `system.power` never-sleep module, an extended Tailscale module with `ssh`, a dedicated non-admin `agent` user (via the existing unified users module), and a headless-safe `roles.agent` home role (development + zellij + claude-code) provisioned inline. Validated on the `vm` host reconfigured as a headless server, then enabled on the desktop.

**Tech Stack:** Nix / NixOS / home-manager / snowfall-lib; SOPS for secrets; Tailscale; zellij.

**Spec:** `docs/specs/2026-08-20-always-on-agent-host-design.md`

**Conventions for every task below:**
- `namespace` = `nix-config`. Modules are auto-discovered by snowfall-lib (no manual imports).
- Verification uses evaluation/build, not unit tests. Prefer fast `nix eval` over full builds where possible.
- Run `just format` before committing; run `just check` (format-check + lint) as the lint gate.
- Commits are signed automatically in this repo. Use Conventional Commits, scope `agent-host`.
- On the `workbook` (darwin) machine, full `nixos-rebuild` builds won't run; use `nix eval`/`nix build .#nixosConfigurations.<host>.config.system.build.toplevel` which evaluate cross-platform, or run builds on a Linux host.

---

## File structure

**Create:**
- `modules/nixos/system/power/default.nix` — `nix-config.system.power.mode` (never-sleep guards; DE-independent).
- `modules/home/roles/agent/default.nix` — headless-safe agent home suite.
- `modules/nixos/roles/agent-host/default.nix` — umbrella role composing the primitives.

**Modify:**
- `modules/nixos/services/networking/tailscale/default.nix` — add `ssh`, `authKeyFile`, `extraUpFlags`.
- `modules/home/cli/tools/gh/default.nix` — parameterize the token secret name (reused for the agent).
- `modules/home/desktops/gnome/default.nix` — drive the power dconf from `system.power.mode` (single source of truth).
- `systems/x86_64-linux/vm/default.nix` + `homes/x86_64-linux/alexander@vm/default.nix` — reconfigure vm as headless agent host (test).
- `systems/x86_64-linux/desktop/default.nix` — enable the role on the desktop (final).

**Secrets (manual SOPS steps, called out in Tasks 7–8):**
- `modules/nixos/secrets.yaml` → `user-agent-password` (required once the `agent` user is declared), optional `tailscale-authkey`.
- `modules/home/secrets.yaml` → `agent-gh-token`.

---

## Task 1: `system.power` never-sleep module

**Files:**
- Create: `modules/nixos/system/power/default.nix`

Design: `mode` defaults to `"default"` (inert — adding the module changes nothing) so it is safe to land before anything consumes it. The agent-host role sets `"no-sleep"`. Note relationship to the existing `modules/nixos/system/hibernation/` module (which only sets a resume device) — this module owns *sleep/suspend inhibition*; they are complementary. Add a one-line comment pointing to hibernation to avoid future confusion.

- [ ] **Step 1: Create the module**

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.power;
in
{
  # Owns sleep/suspend inhibition. See modules/nixos/system/hibernation for the
  # (complementary) resume-device configuration.
  options.${namespace}.system.power = with types; {
    mode = mkOpt (enum [
      "no-sleep"
      "default"
    ]) "default" "Power behavior: 'no-sleep' inhibits all suspend/hibernate (always-on hosts); 'default' leaves normal behavior.";
  };

  config = mkIf (cfg.mode == "no-sleep") {
    # DE-independent guards: mask the sleep targets and stop logind from
    # suspending on idle/lid/power-key. GNOME's own power daemon is handled
    # separately in the GNOME home module, which reads this same option.
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };
  };
}
```

> Note: NixOS 25.11 uses `services.logind.settings.Login.*` (freeform settings). If eval reports these options don't exist on this channel, fall back to the legacy top-level attrs (`services.logind.lidSwitch`, `lidSwitchExternalPower`, `lidSwitchDocked`, and `extraConfig = "IdleAction=ignore";`). Verify in Step 2.

- [ ] **Step 2: Verify it evaluates (option present, inert by default)**

Run:
```bash
nix eval .#nixosConfigurations.desktop.config.nix-config.system.power.mode
```
Expected: `"default"`

Run (confirms the logind attr path is valid on this channel):
```bash
nix eval --impure --expr '((builtins.getFlake (toString ./.)).nixosConfigurations.vm.extendModules { modules = [ { nix-config.system.power.mode = "no-sleep"; } ]; }).config.systemd.targets.sleep.enable'
```
Expected: `false` (and no eval error about `services.logind.settings`). If it errors on logind, apply the fallback in the note and re-run.

- [ ] **Step 3: Format & lint**

Run: `just format && just check`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/system/power/default.nix
git commit -m "feat(agent-host): add system.power never-sleep module"
```

---

## Task 2: Drive GNOME power dconf from `system.power.mode`

**Files:**
- Modify: `modules/home/desktops/gnome/default.nix:75-85`

This makes `system.power` the single source of truth. The home GNOME module reads the NixOS option via `osConfig` (home-manager runs as a NixOS module here, so `osConfig` is available). This is a *replacement* of the hardcoded hibernate values, not additive.

- [ ] **Step 1: Add `osConfig` to the module arguments**

Modify the module's argument set at the top of `modules/home/desktops/gnome/default.nix` to include `osConfig`:

```nix
{
  config,
  osConfig,
  lib,
  namespace,
  ...
}:
```

- [ ] **Step 2: Replace the hardcoded power dconf block**

Replace lines ~75-85 (`"org/gnome/settings-daemon/plugins/power"` and the `idle-delay` session block stays) with a computed version:

```nix
        # Power management — driven by nix-config.system.power.mode so there is a
        # single source of truth (see modules/nixos/system/power). When the host
        # is an always-on "no-sleep" host, GNOME must not hibernate on idle.
        "org/gnome/settings-daemon/plugins/power" =
          let
            noSleep = (osConfig.${namespace}.system.power.mode or "default") == "no-sleep";
          in
          {
            sleep-inactive-ac-timeout = if noSleep then 0 else 7200;
            sleep-inactive-ac-type = if noSleep then "nothing" else "hibernate";
            sleep-inactive-battery-timeout = if noSleep then 0 else 1800;
            sleep-inactive-battery-type = if noSleep then "nothing" else "hibernate";
          };
```

Leave the `"org/gnome/desktop/session".idle-delay = 900;` block unchanged (screen blank/lock is desirable regardless).

- [ ] **Step 3: Verify default behavior is unchanged (desktop, mode still default)**

Run:
```bash
nix eval '.#nixosConfigurations.desktop.config.home-manager.users.alexander.dconf.settings."org/gnome/settings-daemon/plugins/power"."sleep-inactive-ac-type"'
```
Expected: `"hibernate"` (desktop hasn't enabled the role yet, so mode = default).

- [ ] **Step 4: Format, lint, commit**

```bash
just format && just check
git add modules/home/desktops/gnome/default.nix
git commit -m "refactor(agent-host): drive GNOME power dconf from system.power.mode"
```

---

## Task 3: Extend the Tailscale module (`ssh`, `authKeyFile`, `extraUpFlags`)

**Files:**
- Modify: `modules/nixos/services/networking/tailscale/default.nix`

Keep `authKeyFile` optional (null default) so hosts already on the tailnet (desktop) need no secret; a fresh headless host can point it at a SOPS secret.

- [ ] **Step 1: Replace the module body**

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.networking.tailscale;
in
{
  options.${namespace}.services.networking.tailscale = with types; {
    enable = mkEnableOption "Enable tailscale";
    ssh = mkEnableOption "Bring the node up with Tailscale SSH (--ssh), ACL-gated";
    authKeyFile = mkOption {
      type = nullOr str;
      default = null;
      description = "Path to a file containing a Tailscale auth key for non-interactive first-boot join (e.g. a SOPS secret path). Null on hosts already joined.";
    };
    extraUpFlags = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra flags passed to `tailscale up` (escape hatch, e.g. --advertise-exit-node).";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
      extraUpFlags = optional cfg.ssh "--ssh" ++ cfg.extraUpFlags;
    };
  };
}
```

- [ ] **Step 2: Verify**

```bash
nix eval --impure --expr '((builtins.getFlake (toString ./.)).nixosConfigurations.vm.extendModules { modules = [ { nix-config.services.networking.tailscale = { enable = true; ssh = true; }; } ]; }).config.services.tailscale.extraUpFlags'
```
Expected: a list containing `"--ssh"`.

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/nixos/services/networking/tailscale/default.nix
git commit -m "feat(agent-host): tailscale ssh + authKeyFile + extraUpFlags"
```

---

## Task 4: Parameterize the gh token secret name

**Files:**
- Modify: `modules/home/cli/tools/gh/default.nix`

Add a `githubTokenSecret` option (default `"gh-token"`) so the agent home can reuse the exact same pattern with `agent-gh-token`. Existing behavior is unchanged (default preserves `gh-token`).

- [ ] **Step 1: Add the option and use it**

Add to the options block:
```nix
    githubTokenSecret = mkStringOpt "gh-token" "Name of the SOPS home secret holding the GitHub token";
```

Change the `sops.secrets` and `home.sessionVariables` to use it:
```nix
    sops.secrets.${cfg.githubTokenSecret} = mkIf secretEnabled {
      sopsFile = ../../../secrets.yaml;
    };

    home.sessionVariables = mkIf secretEnabled {
      GH_TOKEN = "$(cat ${config.sops.secrets.${cfg.githubTokenSecret}.path})";
    };
```

- [ ] **Step 2: Verify existing default unchanged**

```bash
nix eval '.#nixosConfigurations.desktop.config.home-manager.users.alexander.nix-config.cli.tools.gh.githubTokenSecret'
```
Expected: `"gh-token"`

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/home/cli/tools/gh/default.nix
git commit -m "refactor(agent-host): parameterize gh token secret name"
```

---

## Task 5: `roles.agent` home role

**Files:**
- Create: `modules/home/roles/agent/default.nix`

Headless-safe agent home suite. Enables development (minimal languages to keep builds light — expand later if needed), zellij, claude-code, a distinct git author, keyless signing (via `security.identity.name = "agent"`, no `identities/agent/` folder), and the agent GitHub token via the parameterized gh module.

- [ ] **Step 1: Create the role**

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.agent;
in
{
  options.${namespace}.roles.agent = with types; {
    enable = mkEnableOption "Enable the headless agent home suite (development + zellij + claude-code)";
    gitEmail = mkStringOpt "agent@users.noreply.github.com" "Git author email for the agent's commits";
    gitFullName = mkStringOpt "nix-config agent" "Git author name for the agent's commits";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Keyless identity → unsigned commits (mirrors child accounts; honors the
      # single-GPG-root principle). "agent" has no identities/ folder on purpose.
      security.identity.name = "agent";

      roles.development = {
        enable = true;
        ai = {
          copilot = false;
          claude-code = true;
        };
        languages = {
          typescript = true;
          python = true;
        };
      };

      cli.tools.gh = {
        enable = true;
        githubToken = true;
        githubTokenSecret = "agent-gh-token";
      };

      cli.tools.git = {
        email = cfg.gitEmail;
        fullName = cfg.gitFullName;
      };
    };

    programs.zellij.enable = true;
  };
}
```

> Note: `roles.development` may already enable `cli.tools.git`/`gh`; setting their sub-options here composes via the module system. If eval reports a conflict (e.g. `git.enable` defined twice with `mkForce` somewhere), set only the leaf options shown and do not re-set `.enable`. Verify in Task 7 build.

- [ ] **Step 2: Verify the option exists**

```bash
nix eval '.#nixosConfigurations.desktop.options.nix-config.roles.agent.enable.type.description' 2>/dev/null || echo "option present via role file (confirmed at Task 7 build)"
```
Expected: prints a type description, or the fallback line (full wiring is exercised when a home consumes it in Task 7).

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/home/roles/agent/default.nix
git commit -m "feat(agent-host): add roles.agent headless home suite"
```

---

## Task 6: `roles.agent-host` umbrella role

**Files:**
- Create: `modules/nixos/roles/agent-host/default.nix`

Composes: `system.power.mode = "no-sleep"`, tailscale enable + ssh, the `agent` system user (non-admin), operator SSH public key into the agent's `authorized_keys`, and the agent home provisioned **inline** via `home-manager.users.<agentUser>`.

- [ ] **Step 1: Create the role**

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.agent-host;
  operatorKey = (resolveIdentity config).sshPublicKey;
in
{
  options.${namespace}.roles.agent-host = with types; {
    enable = mkEnableOption "Enable the always-on agent host role";
    agentUser = mkStringOpt "agent" "Name of the dedicated, non-admin agent account";
    powerMode = mkOpt (enum [
      "no-sleep"
      "default"
    ]) "no-sleep" "Power behavior for this host (see nix-config.system.power).";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      system.power.mode = cfg.powerMode;

      services.networking.tailscale = {
        enable = true;
        ssh = true;
      };

      # Dedicated, isolated account. Non-admin → no wheel → cannot sudo.
      users.${cfg.agentUser} = {
        primary = false;
        admin = false;
        profile = "adult";
      };
    };

    # Operator SSH *public* key → agent authorized_keys, so `ssh agent@host`
    # with the operator key works over LAN / tailnet IP alongside Tailscale SSH.
    users.users.${cfg.agentUser}.openssh.authorizedKeys.keys =
      optional (operatorKey != null) operatorKey;

    # Provision the agent home inline (no per-host homes/ file needed).
    home-manager.users.${cfg.agentUser} = {
      nix-config.roles.agent = enabled;
      home.stateVersion = "25.05";
    };
  };
}
```

- [ ] **Step 2: Verify it evaluates**

```bash
nix eval '.#nixosConfigurations.desktop.options.nix-config.roles.agent-host.agentUser.default'
```
Expected: `"agent"`

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/nixos/roles/agent-host/default.nix
git commit -m "feat(agent-host): add roles.agent-host umbrella role"
```

---

## Task 7: Validate headless on the `vm` host

**Files:**
- Modify: `systems/x86_64-linux/vm/default.nix`
- Modify: `homes/x86_64-linux/alexander@vm/default.nix`
- Modify (SOPS, manual): `modules/nixos/secrets.yaml`, `modules/home/secrets.yaml`

This is the real integration test: a headless host with no GNOME. It exercises the DE-independent power guards, inline home provisioning, agent isolation, access, and home persistence.

- [ ] **Step 1: Reconfigure the vm system as headless agent host**

In `systems/x86_64-linux/vm/default.nix`, replace the `roles.graphical` block with the agent-host role:
```nix
  ${namespace} = {
    roles = {
      agent-host = enabled;
    };

    disks.impermanence = enabled;
  };
```

- [ ] **Step 2: Make the operator's vm home headless**

In `homes/x86_64-linux/alexander@vm/default.nix`, remove `roles.graphical` (leave `user.enable = true;` and stylix line can be dropped). Minimal result:
```nix
  nix-config = {
    user = {
      enable = true;
    };
  };

  home.stateVersion = "25.05";
```

- [ ] **Step 3: Add required secrets (manual)**

The users module auto-requires `user-agent-password`, and the agent gh module requires `agent-gh-token`. Add them:
```bash
just secrets-edit nixos   # add: user-agent-password: <hashed password, e.g. from `mkpasswd -m yescrypt`>
just secrets-edit home    # add: agent-gh-token: <a GitHub PAT or classic token>
```
> Tailscale on the throwaway VM: leave `authKeyFile` unset for the build/eval test; join manually post-deploy with an ephemeral key if you want a live tailnet test (see Step 6). The `--ssh` flag and service are checkable without a real join.

- [ ] **Step 4: Build the vm configuration (validates inline provisioning end-to-end)**

Run:
```bash
nix build .#nixosConfigurations.vm.config.system.build.toplevel
```
Expected: builds successfully. This is the point where inline `home-manager.users.agent` is proven to receive the `nix-config` home modules.

> **Fallback if this fails with "The option `nix-config.roles.agent` does not exist"** (snowfall didn't share home modules to inline users): create `homes/x86_64-linux/agent@vm/default.nix` containing `{ ... }: { nix-config.roles.agent.enable = true; home.stateVersion = "25.05"; }`, and remove the `home-manager.users.${cfg.agentUser}` block from the umbrella role (Task 6), documenting that each agent host needs a `homes/<arch>/agent@<host>/` file. Re-run the build. Note this reversal in the spec's decision table.

- [ ] **Step 5: Verify headless power guards and isolation via eval**

```bash
nix eval .#nixosConfigurations.vm.config.systemd.targets.sleep.enable          # expect: false
nix eval .#nixosConfigurations.vm.config.services.tailscale.extraUpFlags        # expect: [ "--ssh" ]
nix eval --json .#nixosConfigurations.vm.config.users.users.agent.extraGroups | grep -q wheel && echo "HAS WHEEL (bad)" || echo "no wheel (good)"
```

- [ ] **Step 6: Deploy to the live VM and verify runtime behavior**

Run (per CLAUDE.md VM workflow):
```bash
just deploy vm --hostname vm --skip-checks
```
Then verify on the VM:
```bash
ssh agent@vm 'id | grep -qv wheel && echo no-sudo-ok'          # agent cannot sudo
ssh agent@vm 'systemctl is-active sleep.target'                 # expect: inactive/masked
ssh agent@vm 'command -v zellij && command -v claude'          # tooling present
ssh agent@vm 'zellij -s test options --help >/dev/null && echo zellij-ok'
ssh agent@vm 'touch ~/persist-check'                            # write to /home/agent
# reboot the VM, then:
ssh agent@vm 'test -f ~/persist-check && echo home-survived-reboot'
```
Expected: each echo prints its success marker; `~/persist-check` survives the reboot (home subvolume).

- [ ] **Step 7: One-time Claude login (subscription OAuth)**

```bash
ssh -t agent@vm 'claude'   # complete the OAuth device/token flow once
ssh agent@vm 'test -f ~/.claude/.credentials.json && echo claude-authed'
```
Reboot once more and re-check `~/.claude/.credentials.json` persists.

- [ ] **Step 8: Commit the vm reconfiguration**

```bash
git add systems/x86_64-linux/vm/default.nix homes/x86_64-linux/alexander@vm/default.nix
git commit -m "test(agent-host): reconfigure vm as headless agent host"
```
> Do NOT commit `secrets.yaml` changes separately — SOPS-encrypted files are committed as part of normal workflow; verify `git diff --stat` shows only encrypted blobs before committing them.

---

## Task 8: Enable on the desktop (production target)

**Files:**
- Modify: `systems/x86_64-linux/desktop/default.nix`

Keep `roles.desktop`; add the agent-host role. On the desktop the power module also neutralizes GNOME's hibernate dconf (Task 2).

- [ ] **Step 1: Enable the role**

In `systems/x86_64-linux/desktop/default.nix`, add to the `${namespace}` block:
```nix
    roles = {
      desktop = {
        enable = true;
      };
      agent-host = enabled;
    };
```

- [ ] **Step 2: Verify GNOME will no longer hibernate**

```bash
nix eval '.#nixosConfigurations.desktop.config.home-manager.users.alexander.dconf.settings."org/gnome/settings-daemon/plugins/power"."sleep-inactive-ac-type"'
```
Expected: `"nothing"`

```bash
nix eval .#nixosConfigurations.desktop.config.systemd.targets.sleep.enable
```
Expected: `false`

- [ ] **Step 3: Build the desktop configuration**

```bash
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
```
Expected: builds successfully.

- [ ] **Step 4: Deploy locally and verify**

```bash
nh os switch
systemctl is-active sleep.target          # expect: inactive
ssh agent@localhost 'echo reachable'      # operator key path
```

- [ ] **Step 5: One-time Claude login on the desktop agent user**

```bash
ssh -t agent@localhost 'claude'           # complete OAuth once
```

- [ ] **Step 6: Format, lint, commit**

```bash
just format && just check
git add systems/x86_64-linux/desktop/default.nix
git commit -m "feat(agent-host): enable agent-host role on desktop"
```

---

## Final verification

- [ ] `just check` passes (format + lint).
- [ ] `nix flake check` passes.
- [ ] `nix build .#nixosConfigurations.vm.config.system.build.toplevel` and `...desktop...` both succeed.
- [ ] On the live desktop: box does not sleep; `ssh agent@<tailnet-name>` works from another tailnet device; a zellij session survives disconnect; Claude Code runs under `agent` and cannot `sudo`.
- [ ] Spec's "Open items" are all resolved or explicitly deferred with a note.

## Notes / deferred (from spec open items)

- **Tailscale SSH vs. openssh on `:22`:** both are enabled. Tailscale SSH handles tailnet connections; openssh handles LAN/other. If a conflict surfaces at runtime, prefer openssh + operator key over the tailnet IP and drop `--ssh` (set `services.networking.tailscale.ssh = false` on that host). Verify during Task 7 Step 6.
- **Firewall enablement** is tracked as separate work (not part of this role); Tailscale manages its own rules, so the role is correct either way.
- **Slim toolchain variant** for weak hosts (RPi): not built (YAGNI). `roles.agent` currently enables typescript+python only; expand per host if needed.
