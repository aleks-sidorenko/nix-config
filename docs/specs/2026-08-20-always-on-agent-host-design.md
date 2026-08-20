# Always-On Agent Host — Design

**Date:** 2026-08-20
**Status:** Approved (design)
**Branch:** `feat/agent-host-role`

## Problem & Goal

Run long-running AI coding agents (Claude Code) on an always-on machine and
reconnect to them from anywhere — close the laptop, the agent keeps working,
reattach later from any device. Deliver this as a **role-based, configurable**
capability that works on the always-on **desktop today** and is **reusable
unchanged on a headless host** (a future VPS or the existing RPi server) with no
desktop environment.

The agent runs `claude --dangerously-skip-permissions` (`cly`), so **isolation is
the central non-functional requirement**: a mistaken or compromised agent must be
contained to a sandboxed service account, not the operator's personal identity.

### Non-goals (YAGNI)

- No managed/cloud agent product; self-hosted only.
- No rented VPS provisioning in this iteration (desktop is the target; headless
  reuse is a design constraint, validated on the `vm` host).
- No unattended/batch agent runner (systemd-service style). Interactive,
  reattachable sessions only.
- No per-workspace container-per-task sandbox in this iteration (the dedicated
  non-admin user is the isolation boundary for now).
- No slim/per-language toolchain variant until a real host strains under the full
  `development` role.

## Decisions (settled during brainstorming)

| Decision | Choice |
|---|---|
| Execution host | Always-on **desktop** now; role reusable on headless hosts |
| Sleep behavior | **Never sleep** by default, configurable via a `mode` knob |
| Who runs agents | **Dedicated non-admin `agent` user** (no `wheel`) |
| Session persistence | **zellij** (interactive, reattachable) |
| Remote access | **Tailscale SSH** (ACL-gated) **+** operator SSH **public** key for direct `ssh agent@host` |
| Claude auth | **Subscription OAuth**, seeded by one-time login, persisted on disk |
| Structure | **Hybrid**: reusable primitives + thin umbrella role (option C) |
| Home provisioning | **Inline** via `home-manager.users.<agent>` in the umbrella role (one switch, no per-host `homes/` file) |
| Agent git identity | **Dedicated `agent` identity** + repo-scoped push credential; operator's private signing/push keys stay off the box |

## Architecture

One **umbrella NixOS role** composes **four reusable primitives**. Nothing new
depends on a desktop environment.

```
nix-config.roles.agent-host        (NEW umbrella role — modules/nixos/roles/agent-host/)
│   one switch + small option surface; composes the pieces below
│
├── system.power                   (NEW module — modules/nixos/system/power/)
│      never-sleep at systemd/logind level (DE-independent);
│      when GNOME present, ALSO neutralizes its power dconf.
│      option: mode = "no-sleep" | "default"
│
├── services.networking.tailscale  (EXTEND existing stub module)
│      add `ssh` option (tailscale up --ssh) + SOPS authKeyFile + extraUpFlags
│
├── nix-config.users.<agentUser>   (declare via existing unified users module)
│      dedicated, NON-admin (no wheel), profile "adult"; SOPS password
│
└── home role: roles.agent         (NEW home role — modules/home/roles/agent/)
       headless-safe: roles.development + zellij + claude-code
       (imported inline via home-manager.users.<agentUser>) — NO graphical deps
```

Cross-cutting, wired by the umbrella role: operator SSH public key into the agent
`authorized_keys`; SOPS secrets (agent password via users module, Tailscale
auth-key). Home persistence is provided by disk layout, not by this role (see
Persistence).

### Consumption

- **Desktop (now):** keep `roles.desktop`; add `roles.agent-host.enable = true`.
  The power module detects GNOME and neutralizes its hibernate dconf *and* sets
  system-level guards.
- **Headless (VPS / RPi / vm test):** `roles.agent-host.enable = true` on a host
  with no DE — the power module only does the system-level guards; inline home
  provisioning supplies the agent's environment with **zero** extra files.

## Component specs

### 1. `system.power` (new module)

Option `nix-config.system.power.mode`:

- **`"no-sleep"`** (umbrella role default): DE-independent guards —
  - disable the sleep targets: `systemd.targets.{sleep,suspend,hibernate,hybrid-sleep}.enable = false`;
  - `services.logind` so idle/lid/power-key never suspend
    (`lidSwitch = "ignore"`, `idleAction = "ignore"` — exact attr names verified at implementation);
  - **when GNOME is enabled** (`config.nix-config.desktops.gnome.enable`), also
    override the GNOME power dconf so it does not hibernate on its idle timer
    (`sleep-inactive-ac-type = "nothing"`, and battery equivalent). Without this,
    GNOME's power daemon hibernates regardless of the logind guards.
- **`"default"`**: module is inert (normal power behavior).

This becomes the **single source of truth** for sleep behavior, replacing the
hardcoded hibernate values currently in
`modules/home/desktops/gnome/default.nix:76-81`. The GNOME override mechanism
(system `programs.dconf` vs. signalling the GNOME home module) is a plan-time
detail; the contract is: one `mode` knob, correct on both headless and GNOME
hosts.

### 2. `services.networking.tailscale` (extend existing stub)

Current module is just `services.tailscale.enable = true`. Add:

- `nix-config.services.networking.tailscale.ssh` (bool) — brings the node up with
  `--ssh` so tailnet-ACL-gated SSH works. Umbrella role sets it `true`.
- `services.tailscale.authKeyFile` → **SOPS secret** `tailscale-authkey`
  (`modules/nixos/secrets.yaml`) for non-interactive first-boot join on a fresh
  headless host. No-op on the already-authenticated desktop.
- `extraUpFlags` passthrough (default `[]`) as an escape hatch (e.g.
  `--advertise-exit-node`); not populated now.
- `services.tailscale` manages its own firewall/interface trust; nothing extra is
  needed while the global firewall is off, and it stays correct if the firewall
  is later enabled on a VPS.

### 3. Agent system user (via unified users module)

- `nix-config.users.${agentUser}`: `primary = false`, `admin = false` (no
  `wheel` → `cly`/skip-permissions cannot `sudo`), `profile = "adult"`.
- SOPS password `user-${agentUser}-password` provisioned automatically by the
  users module.
- **Operator access:** umbrella role adds the operator's primary identity
  `ssh.pub` (resolved from `identities/` via the existing authorizedKeys helper)
  to the agent user's `authorized_keys`, enabling `ssh agent@host` with the
  operator key over LAN or the tailnet IP, independent of Tailscale SSH.

### 4. `roles.agent` (new home role)

Headless-safe; imported inline via `home-manager.users.${agentUser}` from the
umbrella role:

- Enable `roles.development` (git, nvim, direnv, language toolchains, podman) —
  already DE-independent.
- Add `programs.zellij` — the persistent, reattachable session interface.
- Enable `roles.development.ai.claude-code` (today only switched on inside the
  desktop role; make it independently enable-able here).
- **No** graphical/desktop/parent roles.

## Access model

Two independent paths reach the agent user; the role guarantees both:

1. **Tailscale SSH** — ACL-gated, no key distribution, reachable from any tailnet
   device; never exposes port 22 publicly.
2. **Operator SSH public key** — `ssh agent@host` with the operator's key over
   LAN or the tailnet IP.

The hardened `openssh` module stays enabled alongside Tailscale SSH.
**Plan-time detail to resolve:** exact behavior when both Tailscale SSH and
`openssh` want tailnet `:22`. Fallback if they conflict: rely on `openssh` + key
auth over the tailnet IP and drop `--ssh`, or keep both with Tailscale SSH taking
the tailnet path. The design guarantee is that both an ACL path and a
key path reach the agent user.

## Identity & credentials

- **Dedicated `agent` identity** under `identities/agent/` (own SSH signing key,
  own git name/email, own `ssh.pub`/`gpg` material) — agent commits are
  attributable and signed with a key that is not the operator's.
- **Repo-scoped push credential** for the agent (fine-grained PAT or deploy key —
  exact choice a plan detail), not the operator's personal token.
- Operator's **private** signing/push keys are **never** placed on the box. Only
  the operator's SSH **public** key is added, for login convenience.

Rationale: the agent runs skip-permissions; blast radius on mistake/compromise
must be a sandboxed bot account with independently revocable, narrowly-scoped
credentials — the standard machine/service-identity pattern (as CI uses).

## Persistence

The desktop wipes only the `@root` subvolume on boot
(`modules/nixos/disks/impermanence/default.nix`). `/home` is a **separate btrfs
subvolume** (`systems/x86_64-linux/desktop/disks.nix`, `data` disk) that is never
touched. Therefore:

- **Agent home state survives automatically**: `~/.claude/.credentials.json` (the
  OAuth login), projects/clones, zellij config, `~/.ssh`, and the agent push
  credential all live under `/home/agent`. The role adds **nothing** to
  impermanence for home (doing so would be redundant/incorrect).
- **Non-home runtime state** is already covered: Tailscale state at
  `/var/lib/tailscale` falls under the existing `/var/lib/` persistence
  whitelist, so the node stays authenticated across reboots.
- **One-time bootstrap** (documented, not declarative): after first deploy,
  `ssh agent@host`, run `claude` once to complete subscription OAuth; the
  credential lands in the persisted `/home/agent/.claude/`.

**Prerequisite for headless reuse:** free home persistence depends on the host's
disk layout providing a persistent `/home` (as desktop and vm do). A host without
one must either follow the same separate-`/home`-subvolume convention or add the
agent home to impermanence in its own `disks.nix`. The role documents this
prerequisite rather than dictating disk layout.

## Secrets (SOPS)

- `user-${agentUser}-password` — auto-created by the users module.
- `tailscale-authkey` — new secret in `modules/nixos/secrets.yaml` for headless
  first-boot join (unused on the already-joined desktop).
- Agent push credential material — stored under the persisted agent home (seeded
  during bootstrap) rather than as a Nix-managed secret, or as a SOPS home secret
  following the `gh-token` pattern (`modules/home/cli/tools/gh/default.nix`) —
  decided at plan time based on the credential type chosen.

## Testing — validate headless on the `vm` host

The `vm` host is the headless test bed: it already has a persistent `home`
subvolume and impermanence enabled (`systems/x86_64-linux/vm/{default,disks}.nix`),
and is provisioned via Vagrant.

**Transformation:** switch `vm` from the `graphical` role to headless agent host —
remove `roles.graphical` from `systems/x86_64-linux/vm/default.nix` (and simplify
`homes/x86_64-linux/alexander@vm` accordingly), and set
`roles.agent-host.enable = true`.

**What this exercises (the headless path specifically):**

1. `system.power` with `mode = "no-sleep"` on a host with **no GNOME** — only the
   systemd/logind guards apply; verify sleep targets are masked and logind
   ignores idle.
2. **Inline home provisioning** — enabling the umbrella role creates the `agent`
   user and its full home (development + zellij + claude-code) with no `homes/`
   file.
3. **Agent user isolation** — `agent` exists, is not in `wheel`, cannot `sudo`.
4. **Access** — `ssh agent@vm` with the operator key succeeds; zellij session
   starts, detaches, and reattaches.
5. **Home persistence** — write a file under `/home/agent`, reboot the vm, confirm
   it survives the root wipe.

**Test caveats:**

- Tailscale join in a throwaway Vagrant VM needs an auth key. For the vm test,
  either use an ephemeral SOPS auth-key or skip the actual tailnet join and
  validate via `openssh` + operator key (the `vm` already imports GitHub SSH
  keys). The `--ssh` flag and service coming up are the checkable units; a real
  tailnet join is validated on the desktop.
- The one-time `claude` OAuth login is manual; on the vm it validates the
  credential lands in and persists under `/home/agent/.claude/`.

**Validation commands** (from CLAUDE.md): `just check` (format + lint),
`just build` / `nix flake check`, then `just deploy vm --hostname vm
--skip-checks` for the live VM.

## Open items for the implementation plan

- Exact GNOME dconf override mechanism (system `programs.dconf` vs. GNOME home
  module signal).
- Tailscale SSH vs. `openssh` `:22` coexistence resolution.
- Agent push-credential type (fine-grained PAT vs. deploy key) and where it is
  seeded/stored.
- Whether `roles.development`'s full toolchain is acceptable on the target hosts
  or a slim toggle is needed (defer unless a host strains).
- `system.power` GNOME override should replace, not conflict with, the existing
  hardcoded values in `modules/home/desktops/gnome/default.nix`.
