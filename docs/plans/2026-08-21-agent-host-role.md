# Agent Host Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable, configurable `nix-config.roles.agent-host` role that turns any host (desktop now, headless VPS/server later) into an always-on box running Claude Code under an isolated `agent` user, reachable over Tailscale SSH.

**Architecture:** One umbrella NixOS role composes four reusable primitives — a DE-independent `system.power` never-sleep module, an extended Tailscale module with `ssh`, a dedicated non-admin `agent` user (via the existing unified users module), and a headless-safe `roles.agent` home role (common + development + zellij + claude-code) provisioned inline. The agent is keyless (unsigned commits, single-GPG-root principle), so its GitHub push token is delivered via **NixOS** SOPS (host age key), not home SOPS. Validated on the `vm` host reconfigured as a headless server, then enabled on the desktop.

**Tech Stack:** Nix / NixOS / home-manager / snowfall-lib; SOPS; Tailscale; zellij.

**Spec:** `docs/specs/2026-08-20-always-on-agent-host-design.md`

**Conventions for every task below:**
- `namespace` = `nix-config`. Modules are auto-discovered by snowfall-lib (no manual imports).
- Verification uses evaluation/build, not unit tests. Prefer fast `nix eval` over full builds.
- Run `just format` before committing; run `just check` (format-check + lint) as the lint gate.
- Commits are signed automatically in this repo. Use Conventional Commits, scope `agent-host`.
- On `workbook` (darwin), full `nixos-rebuild` won't run; `nix eval` / `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` evaluate cross-platform.

---

## File structure

**Create:**
- `modules/nixos/system/power/default.nix` — `nix-config.system.power.mode` (never-sleep guards; DE-independent).
- `modules/home/roles/agent/default.nix` — headless-safe agent home suite.
- `modules/nixos/roles/agent-host/default.nix` — umbrella role composing the primitives + NixOS-SOPS token delivery.

**Modify:**
- `modules/nixos/services/networking/tailscale/default.nix` — add `ssh`, `authKeyFile`, `extraUpFlags`.
- `modules/home/desktops/gnome/default.nix` — drive the power dconf from `system.power.mode`.
- `systems/x86_64-linux/vm/default.nix` + `homes/x86_64-linux/alexander@vm/default.nix` — reconfigure vm as headless agent host (test).
- `systems/x86_64-linux/desktop/default.nix` — enable the role on the desktop (final).

**Secrets (manual SOPS, called out in Tasks 6–7):**
- `modules/nixos/secrets.yaml` → `user-agent-password` (required once the `agent` user is declared), `agent-gh-token` (the agent's GitHub token), optional `tailscale-authkey`.

> Note: the agent's GitHub token lives in **NixOS** SOPS (not `modules/home/secrets.yaml`), because home SOPS decrypts via the user's GPG key and the `agent` user is intentionally keyless. NixOS SOPS decrypts with the host age key, which every host has.

---

## Task 1: `system.power` never-sleep module

**Files:**
- Create: `modules/nixos/system/power/default.nix`

`mode` defaults to `"default"` (inert) so it is safe to land before anything consumes it; the agent-host role sets `"no-sleep"`. Owns *sleep/suspend inhibition*; the existing `modules/nixos/system/hibernation/` (resume device only) is complementary.

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
    # DE-independent guards: mask the sleep targets and stop logind suspending on
    # idle/lid/power-key. GNOME's own power daemon is handled in the GNOME home
    # module, which reads this same option.
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

- [ ] **Step 2: Verify (option present + inert default + no-sleep masks targets)**

```bash
nix eval .#nixosConfigurations.desktop.config.nix-config.system.power.mode
# expect: "default"
nix eval --impure --expr '((builtins.getFlake (toString ./.)).nixosConfigurations.vm.extendModules { modules = [ { nix-config.system.power.mode = "no-sleep"; } ]; }).config.systemd.targets.sleep.enable'
# expect: false  (and no eval error about services.logind.settings — confirmed valid on nixos-25.11)
```

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/nixos/system/power/default.nix
git commit -m "feat(agent-host): add system.power never-sleep module"
```

---

## Task 2: Drive GNOME power dconf from `system.power.mode`

**Files:**
- Modify: `modules/home/desktops/gnome/default.nix` (arguments; power dconf block lines **76-81**)

Makes `system.power` the single source of truth. Home-manager runs as a NixOS module here, so `osConfig` is available.

- [ ] **Step 1: Add `osConfig` to the module arguments**

```nix
{
  config,
  osConfig,
  lib,
  namespace,
  ...
}:
```

- [ ] **Step 2: Replace the power dconf block (lines 76-81 only; leave `idle-delay` at 83-85 untouched)**

```nix
        # Power management — driven by nix-config.system.power.mode (single source
        # of truth; see modules/nixos/system/power). An always-on "no-sleep" host
        # must not hibernate on idle.
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

- [ ] **Step 3: Verify default unchanged (desktop, role not yet enabled)**

```bash
nix eval '.#nixosConfigurations.desktop.config.home-manager.users.alexander.dconf.settings."org/gnome/settings-daemon/plugins/power"."sleep-inactive-ac-type"'
# expect: "hibernate"
```

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
      description = "Path to a file with a Tailscale auth key for non-interactive first-boot join (e.g. a SOPS secret path). Null on hosts already joined.";
    };
    extraUpFlags = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra flags for `tailscale up` (escape hatch, e.g. --advertise-exit-node). NOTE: upstream applies these only when authKeyFile is set; for flags that must apply without an auth key, prefer `tailscale set`.";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile extraUpFlags;
      # `--ssh` MUST go through extraSetFlags (drives tailscaled-set): upstream
      # applies extraUpFlags only via tailscaled-autoconnect, which is gated on
      # authKeyFile != null. Our always-on hosts join interactively (no auth key),
      # so routing --ssh through extraUpFlags would silently no-op.
      extraSetFlags = optional cfg.ssh "--ssh";
    };
  };
}
```

- [ ] **Step 2: Verify**

```bash
nix eval --impure --expr '((builtins.getFlake (toString ./.)).nixosConfigurations.vm.extendModules { modules = [ { nix-config.services.networking.tailscale = { enable = true; ssh = true; }; } ]; }).config.services.tailscale.extraSetFlags'
# expect: a list containing "--ssh"
```

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/nixos/services/networking/tailscale/default.nix
git commit -m "feat(agent-host): tailscale ssh + authKeyFile + extraUpFlags"
```

---

## Task 4: `roles.agent` home role

**Files:**
- Create: `modules/home/roles/agent/default.nix`

Headless-safe agent home suite. Enables `roles.common` (shell essentials — starship/eza/bat/zoxide/fzf/fish/nvim; its home SOPS stays inert because the agent declares no home secrets) and `roles.development` (which enables `cli.tools.gh`). Keyless identity → unsigned commits. Because the agent has **no SSH key**, git pushes over **HTTPS using `GH_TOKEN`** via a gh credential helper; `GH_TOKEN` itself is injected by the umbrella role (Task 5) from a NixOS SOPS secret.

- [ ] **Step 1: Create the role**

```nix
{
  config,
  lib,
  pkgs,
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
      roles.common = enabled;

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

      cli.tools.git = {
        email = cfg.gitEmail;
        fullName = cfg.gitFullName;
      };
    };

    # Keyless agent → push over HTTPS with GH_TOKEN (injected by the umbrella
    # role). Rewrite SSH remotes to HTTPS and let gh serve credentials.
    programs.git.settings = {
      url."https://github.com/".insteadOf = "git@github.com:";
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };

    programs.zellij.enable = true;
  };
}
```

> Note: `roles.development` already sets `cli.tools.gh.enable = true` and leaves `githubToken` off (see its comment at `modules/home/roles/development/default.nix:140`). We deliberately do NOT set `githubToken = true` for the agent — that path uses home SOPS (GPG), which a keyless user cannot decrypt. Token comes from NixOS SOPS instead (Task 5).
>
> Two harmless-but-worth-knowing points: (a) the shared gh module sets `git_protocol = "ssh"`, so pure-`gh` flows (`gh pr create`, `gh repo clone`) default to SSH; `git push` is covered by the `insteadOf` rewrite + credential helper above, but if a `gh` subcommand needs HTTPS, set `programs.gh.settings.git_protocol = lib.mkForce "https"` for the agent. (b) The agent is the first `roles.common` home with no `styles.stylix.wallpaper` set — verified safe (the repo pins `base16Scheme`, so stylix needs no image), noted here to preempt confusion.

- [ ] **Step 2: Verify the option is registered**

```bash
nix eval '.#nixosConfigurations.desktop.options.nix-config.roles.agent.enable.type.name' 2>/dev/null || echo "confirmed at Task 6 build"
```

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/home/roles/agent/default.nix
git commit -m "feat(agent-host): add roles.agent headless home suite"
```

---

## Task 5: `roles.agent-host` umbrella role (+ NixOS-SOPS token delivery)

**Files:**
- Create: `modules/nixos/roles/agent-host/default.nix`

Composes power/tailscale/user/home, adds the operator's SSH public key to the agent's `authorized_keys`, and delivers `GH_TOKEN` from a NixOS SOPS secret owned by the agent user.

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
  sopsEnabled = config.${namespace}.security.sops.enable;
  tokenSecret = "agent-gh-token";
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

    # Operator SSH *public* key → agent authorized_keys (ssh agent@host with the
    # operator key, over LAN / tailnet IP, alongside Tailscale SSH).
    users.users.${cfg.agentUser}.openssh.authorizedKeys.keys =
      optional (operatorKey != null) operatorKey;

    # Agent GitHub token via NixOS SOPS (host age key), owned by the agent user.
    sops.secrets.${tokenSecret} = mkIf sopsEnabled {
      sopsFile = ../../secrets.yaml;
      owner = cfg.agentUser;
      mode = "0400";
    };

    # Provision the agent home inline (no per-host homes/ file needed) and inject
    # GH_TOKEN from the NixOS secret path.
    home-manager.users.${cfg.agentUser} = {
      nix-config.roles.agent = enabled;
      home.stateVersion = "25.05";
      home.sessionVariables = mkIf sopsEnabled {
        GH_TOKEN = "$(cat ${config.sops.secrets.${tokenSecret}.path})";
      };
    };
  };
}
```

> Path check: `modules/nixos/roles/agent-host/default.nix` → `../../secrets.yaml` resolves to `modules/nixos/secrets.yaml`. Confirm during Step 2.

- [ ] **Step 2: Verify it evaluates**

```bash
nix eval '.#nixosConfigurations.desktop.options.nix-config.roles.agent-host.agentUser.default'
# expect: "agent"
```

- [ ] **Step 3: Format, lint, commit**

```bash
just format && just check
git add modules/nixos/roles/agent-host/default.nix
git commit -m "feat(agent-host): add roles.agent-host umbrella role"
```

---

## Task 6: Validate headless on the `vm` host

**Files:**
- Modify: `systems/x86_64-linux/vm/default.nix`
- Modify: `homes/x86_64-linux/alexander@vm/default.nix`
- Modify (SOPS, manual): `modules/nixos/secrets.yaml`

The real integration test: a headless host with no GNOME. Exercises DE-independent power guards, inline home provisioning, agent isolation, access, token delivery, and home persistence.

- [ ] **Step 1: Reconfigure the vm system as headless agent host**

In `systems/x86_64-linux/vm/default.nix`, replace the `roles.graphical` block:
```nix
  ${namespace} = {
    roles = {
      agent-host = enabled;
    };

    disks.impermanence = enabled;
  };
```

- [ ] **Step 2: Make the operator's vm home headless**

In `homes/x86_64-linux/alexander@vm/default.nix`, remove `roles.graphical` and the stylix line. Minimal result:
```nix
  nix-config = {
    user = {
      enable = true;
    };
  };

  home.stateVersion = "25.05";
```

- [ ] **Step 3: Add required NixOS secrets (manual)**

```bash
just secrets-edit nixos
# add:
#   user-agent-password: <hashed pw, e.g. `mkpasswd -m yescrypt`>
#   agent-gh-token: <a GitHub PAT or classic token for the agent's machine account>
```
> Leave `tailscale-authkey` out for the build/eval test; join the throwaway VM manually post-deploy if you want a live tailnet test.

- [ ] **Step 4: Build the vm (proves inline home provisioning end-to-end)**

```bash
nix build .#nixosConfigurations.vm.config.system.build.toplevel
```
Expected: builds successfully — this is where inline `home-manager.users.agent` is proven to receive the `nix-config` home modules (snowfall adds `modules/home/*` to `home-manager.sharedModules`).

> **Fallback if it fails with "The option `nix-config.roles.agent` does not exist"**: create `homes/x86_64-linux/agent@vm/default.nix` = `{ ... }: { nix-config.roles.agent.enable = true; home.stateVersion = "25.05"; }`, remove the `home-manager.users.${cfg.agentUser}` block from Task 5, and move the `GH_TOKEN` sessionVariable into that home file (reading the NixOS secret path via `osConfig`). Document that each agent host then needs a `homes/<arch>/agent@<host>/` file, and note the reversal in the spec.

- [ ] **Step 5: Verify power guards + isolation via eval**

```bash
nix eval .#nixosConfigurations.vm.config.systemd.targets.sleep.enable                 # expect: false
nix eval .#nixosConfigurations.vm.config.services.tailscale.extraUpFlags               # expect: [ "--ssh" ]
nix eval --json .#nixosConfigurations.vm.config.users.users.agent.extraGroups | grep -q wheel && echo "HAS WHEEL (bad)" || echo "no wheel (good)"
```

- [ ] **Step 6: Deploy to the live VM and verify runtime behavior**

```bash
just deploy vm --hostname vm --skip-checks
```
On the VM:
```bash
ssh agent@vm 'id | tr "," "\n" | grep -q wheel && echo HAS-WHEEL-bad || echo no-sudo-ok'
ssh agent@vm 'systemctl is-enabled sleep.target || echo sleep-masked-ok'
ssh agent@vm 'command -v zellij && command -v claude'
ssh agent@vm 'test -n "$GH_TOKEN" && echo token-present-ok'          # NixOS-SOPS token reached the shell
ssh agent@vm 'gh auth status 2>&1 | grep -qi "logged in\|token" && echo gh-token-ok || echo gh-token-check-manual'
ssh agent@vm 'touch ~/persist-check'
# reboot the VM, then:
ssh agent@vm 'test -f ~/persist-check && echo home-survived-reboot'
```
Expected: `no-sudo-ok`, `sleep-masked-ok`, tooling present, `token-present-ok`, and `~/persist-check` survives the reboot.

- [ ] **Step 7: One-time Claude login (subscription OAuth) + push smoke test**

```bash
ssh -t agent@vm 'claude'   # complete OAuth once
ssh agent@vm 'test -f ~/.claude/.credentials.json && echo claude-authed'
# optional real push test in a scratch repo the agent's token can write to:
ssh agent@vm 'cd $(mktemp -d) && git init -q && git remote add origin https://github.com/<agent-writable-repo>.git && echo "verify push manually"'
```
Reboot once more; re-check `~/.claude/.credentials.json` persists.

> If the HTTPS credential-helper push proves fiddly, it is an acceptable follow-up: Claude Code auth is OAuth (works independently), and commits/local work are unaffected. Note it and move on rather than blocking.

- [ ] **Step 8: Commit the vm reconfiguration**

```bash
git add systems/x86_64-linux/vm/default.nix homes/x86_64-linux/alexander@vm/default.nix modules/nixos/secrets.yaml
git commit -m "test(agent-host): reconfigure vm as headless agent host"
```
> Before committing `secrets.yaml`, run `git diff --stat` and confirm it shows only the encrypted blob (never plaintext).

---

## Task 7: Enable on the desktop (production target)

**Files:**
- Modify: `systems/x86_64-linux/desktop/default.nix`

Keep `roles.desktop`; add the agent-host role. On the desktop the power module also neutralizes GNOME's hibernate dconf (Task 2). The desktop already has `agent-gh-token`/`user-agent-password` available only if added to `modules/nixos/secrets.yaml` (Task 6 added them; they are shared across hosts via `.sops.yaml`).

- [ ] **Step 1: Enable the role**

In `systems/x86_64-linux/desktop/default.nix`, in the `${namespace}` block:
```nix
    roles = {
      desktop = {
        enable = true;
      };
      agent-host = enabled;
    };
```

- [ ] **Step 2: Verify GNOME no longer hibernates + targets masked**

```bash
nix eval '.#nixosConfigurations.desktop.config.home-manager.users.alexander.dconf.settings."org/gnome/settings-daemon/plugins/power"."sleep-inactive-ac-type"'
# expect: "nothing"
nix eval .#nixosConfigurations.desktop.config.systemd.targets.sleep.enable
# expect: false
```

- [ ] **Step 3: Build**

```bash
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
```

- [ ] **Step 4: Deploy locally and verify**

```bash
nh os switch
systemctl is-enabled sleep.target || echo sleep-masked-ok
ssh agent@localhost 'echo reachable && test -n "$GH_TOKEN" && echo token-ok'
```

- [ ] **Step 5: One-time Claude login on the desktop agent user**

```bash
ssh -t agent@localhost 'claude'
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
- [ ] `nix build .#nixosConfigurations.vm...toplevel` and `...desktop...` both succeed.
- [ ] Live desktop: box does not sleep; `ssh agent@<tailnet-name>` works from another tailnet device; a zellij session survives disconnect; Claude Code runs under `agent` and cannot `sudo`; `$GH_TOKEN` is set in the agent shell.
- [ ] Spec's "Open items" are all resolved or explicitly deferred with a note.

## Notes / deferred (from spec open items)

- **Tailscale SSH vs. openssh on `:22`:** both enabled. Tailscale SSH handles tailnet connections; openssh handles LAN/other. If a runtime conflict surfaces, prefer openssh + operator key over the tailnet IP and set `services.networking.tailscale.ssh = false` on that host. Verify during Task 6 Step 6.
- **Git push for the keyless agent** is HTTPS + `GH_TOKEN` via a gh credential helper (Task 4). If the helper wiring is fiddly, it is a documented follow-up — Claude OAuth and local commits are unaffected.
- **Firewall enablement** is separate work (not part of this role); Tailscale manages its own rules, so the role is correct either way.
- **Slim toolchain variant** for weak hosts (RPi): not built (YAGNI). `roles.agent` enables typescript+python only; expand per host if needed.
