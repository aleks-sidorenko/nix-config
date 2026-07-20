# Parent role — on-demand child internet control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a parent a `child-net block|unblock|status` command that cuts off (and restores) the child's devices' public internet by toggling their membership in the router's `banned` address-list over SSH.

**Architecture:** A generic, host-agnostic `router-net` primitive lives in `roles.router-manager` and mutates the router's existing `banned` address-list over SSH (reusing the already-declared `forward_drop_banned_external` drop rule). A new policy layer `roles.parent` wires the child's device list into a thin `child-net` wrapper. The router's declared baseline flips to an empty `banned` list so "internet allowed" is the default and blocking is additive.

**Tech Stack:** Nix (snowfall-lib modules), `pkgs.writeShellApplication` (build-time shellcheck), terranix/`nix-routeros`, RouterOS CLI over SSH.

**Spec:** `docs/specs/2026-07-20-parent-child-net-control-design.md`

**Conventions for this repo:**
- Modules use `with lib;` + `with lib.${namespace};`; `defaults` (from `lib/defaults`) and helpers (`mkOpt`, `mkEnableOption`, `enabled`) are in scope unqualified.
- Scripts use `pkgs.writeShellApplication` (as in `modules/home/security/sops/default.nix`) — it injects `set -euo pipefail` and runs **shellcheck at build time**, which is our primary automated test for shell correctness.
- `docs/specs/` and `docs/plans/` are gitignored-but-tracked — stage them with `git add -f`.
- Commit messages: Conventional Commits.

---

## File Structure

- `infra/router/default.nix` — **modify**: `firewall.addressLists.banned` seeded list → `[ ]`.
- `infra/router/README.md` — **modify**: document the runtime-vs-`router-apply` trade-off.
- `modules/home/roles/router-manager/default.nix` — **modify**: add the generic `router-net` command (keep `winbox4`).
- `modules/home/roles/parent/default.nix` — **create**: `parent` role, `childDevices` option, `child-net` wrapper, enables `router-manager`.
- `homes/x86_64-linux/alexander@homebook/default.nix` — **modify**: enable `roles.parent` (the family laptop the parent uses). *(Optionally also `alexander@desktop`; see Task 4 note.)*

---

## Task 1: Flip router baseline to an empty `banned` list

**Files:**
- Modify: `infra/router/default.nix` (the `firewall.addressLists.banned` attribute)
- Modify: `infra/router/README.md`

- [ ] **Step 1: Confirm current state**

Run: `grep -n -A6 "addressLists.banned" infra/router/default.nix`
Expected: shows `banned = [ ...tv ...tv-wifi ...homebook ...ipad ];`

- [ ] **Step 2: Replace the seeded list with an empty list**

In `infra/router/default.nix`, change:

```nix
          firewall = {
            addressLists.banned = [
              defaults.network.hosts.tv
              defaults.network.hosts.tv-wifi
              defaults.network.hosts.homebook
              defaults.network.hosts.ipad
            ];
```

to:

```nix
          firewall = {
            # Baseline: nobody blocked. Membership is managed at runtime by the
            # `router-net` / `child-net` commands (see modules/home/roles/{router-manager,parent}).
            # A manual `just router-apply` re-asserts this empty baseline, clearing
            # any active runtime block.
            addressLists.banned = [ ];
```

Leave `filterRules` (the `forward_drop_banned_external` rule) unchanged.

- [ ] **Step 3: Add a note to the router README**

In `infra/router/README.md`, add a short section documenting that `banned` is empty by declaration, that runtime blocking is done via `router-net`/`child-net`, and that `just router-apply` resets everyone to online.

- [ ] **Step 4: Verify the config still evaluates and generates valid terraform**

Run: `nix run .#router` (a.k.a. `just router-show`)
Expected: generates terraform JSON without error; the `banned` address-list resource(s) for the four hosts are **gone** from the output (or the list is empty). Do **not** run `router-apply` here.

- [ ] **Step 5: Format + commit**

```bash
just format infra/router/default.nix
git add infra/router/default.nix infra/router/README.md
git commit -m "feat(router): empty banned baseline; runtime membership is the control knob"
```

---

## Task 2: Generic `router-net` primitive in `roles.router-manager`

Adds a host-agnostic block/unblock/status command. It resolves friendly host names to IPs from `defaults.network.hosts`, reuses the existing `banned` list, flushes live connections on block, and is idempotent (remove-then-add). A `ROUTER_SSH` override seam makes the generated RouterOS commands testable without a live router.

**Files:**
- Modify: `modules/home/roles/router-manager/default.nix`

- [ ] **Step 1: Add the `router-net` derivation and install it**

Rewrite `modules/home/roles/router-manager/default.nix` to:

```nix
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.router-manager;

  # name→IP resolution baked from the single source of truth (lib/defaults).
  hostCases = concatStringsSep "\n    " (
    mapAttrsToList (name: ip: "${name}) echo ${ip} ;;") defaults.network.hosts
  );
  knownNames = concatStringsSep " " (attrNames defaults.network.hosts);

  # Generic, host-agnostic router control. Knows nothing about child/parent.
  # Mutates the terranix-declared `banned` address-list (the one fed to the
  # always-on forward_drop_banned_external rule). SSH transport is overridable
  # via ROUTER_SSH (a single command taking the RouterOS script as one arg) for
  # testing; default is `ssh router` (same alias router-backup uses).
  router-net = pkgs.writeShellApplication {
    name = "router-net";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      usage() {
        cat >&2 <<'EOF'
      usage:
        router-net block   <host|ip>...   add hosts to the router `banned` list (+ drop live connections)
        router-net unblock <host|ip>...   remove hosts from the `banned` list
        router-net status                 print current `banned` members
      EOF
        exit 2
      }

      resolve() {
        case "$1" in
          ${hostCases}
          *)
            if [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
              echo "$1"
            else
              echo "router-net: unknown host '$1'. Known: ${knownNames}" >&2
              return 1
            fi
            ;;
        esac
      }

      run_on_router() {
        # $1 = RouterOS command script (possibly multi-line)
        if [[ -n "''${ROUTER_SSH:-}" ]]; then
          "''${ROUTER_SSH}" "$1"
        else
          ssh router "$1"
        fi
      }

      cmd="''${1:-}"; shift || true
      case "$cmd" in
        block)
          [[ $# -ge 1 ]] || usage
          script=""
          for h in "$@"; do
            ip="$(resolve "$h")" || exit 1
            esc="''${ip//./\\.}"
            script+="/ip firewall address-list remove [find where list=banned address=$ip]"$'\n'
            script+="/ip firewall address-list add list=banned address=$ip comment=router-net"$'\n'
            script+="/ip firewall connection remove [find where src-address~\"^$esc:\"]"$'\n'
          done
          run_on_router "$script"
          echo "blocked: $*"
          ;;
        unblock)
          [[ $# -ge 1 ]] || usage
          script=""
          for h in "$@"; do
            ip="$(resolve "$h")" || exit 1
            script+="/ip firewall address-list remove [find where list=banned address=$ip]"$'\n'
          done
          run_on_router "$script"
          echo "unblocked: $*"
          ;;
        status)
          run_on_router '/ip firewall address-list print where list=banned'
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.winbox4
      router-net
    ];
  };
}
```

- [ ] **Step 2: Write a build-time test that the generated RouterOS commands are correct**

The `writeShellApplication` shellcheck pass already validates shell syntax at build. The behavioral test of command generation uses the `ROUTER_SSH` seam and runs in Task 5 Step 4 (once the binary is on PATH in a built home).

**Important — the stub must be a single-word command.** `run_on_router` invokes the transport as `"${ROUTER_SSH}" "$1"` (quoted, to satisfy shellcheck). A double-quoted expansion never word-splits, so `ROUTER_SSH` must name a single command that takes the RouterOS script as one argument. Use `ROUTER_SSH=echo` (prints the multi-line arg verbatim). Do **not** use `ROUTER_SSH="printf %s\n"` (bash would look for a command literally named `printf %s\n` → 127) and do **not** unquote `${ROUTER_SSH}` (trips shellcheck SC2086 and fails the build).

Expected output for `ROUTER_SSH=echo router-net block tv` (stub echoes its single argument):
```
/ip firewall address-list remove [find where list=banned address=10.0.0.50]
/ip firewall address-list add list=banned address=10.0.0.50 comment=router-net
/ip firewall connection remove [find where src-address~"^10\.0\.0\.50:"]
```
And `ROUTER_SSH=echo router-net block bogushost` exits non-zero with `unknown host 'bogushost'`.

> Note for executor: the inline-module form can't be `nix build`'d in isolation without wiring. The authoritative shellcheck + eval happens in Task 5 (`just build` of `alexander@homebook`). Run the `ROUTER_SSH=echo` behavioral checks there, once the binary is on PATH.

- [ ] **Step 3: Lint + format**

Run: `just format modules/home/roles/router-manager/default.nix && just lint`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add modules/home/roles/router-manager/default.nix
git commit -m "feat(router-manager): generic router-net block/unblock/status over SSH"
```

---

## Task 3: New `roles.parent` policy layer with `child-net`

**Files:**
- Create: `modules/home/roles/parent/default.nix`

- [ ] **Step 1: Create the parent role module**

Create `modules/home/roles/parent/default.nix`:

```nix
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.parent;

  # Resolve the child device names to IPs (for the focused status filter) from
  # the single source of truth. `childDevices` are validated below.
  childIps = map (name: defaults.network.hosts.${name}) cfg.childDevices;
  childIpRegex = concatStringsSep "|" (map (ip: replaceStrings [ "." ] [ "\\." ] ip) childIps);
  devicesArgs = escapeShellArgs cfg.childDevices;

  # Thin policy wrapper over the generic `router-net` (installed via the
  # router-manager role this role enables). Contains no router logic of its own;
  # it only bakes in the child device list and a display filter for `status`.
  # NOTE: no pkgs.stdenv.isLinux assertion — this runs from the parent's own
  # machine, which may be the darwin workbook (unlike roles.child).
  child-net = pkgs.writeShellApplication {
    name = "child-net";
    runtimeInputs = [ pkgs.gnugrep ]; # router-net is an ambient PATH dep (installed by roles.router-manager)
    text = ''
      case "''${1:-}" in
        block)   exec router-net block ${devicesArgs} ;;
        unblock) exec router-net unblock ${devicesArgs} ;;
        status)
          if router-net status | grep -E '${childIpRegex}'; then
            :
          else
            echo "(no child devices currently blocked)"
          fi
          ;;
        *)
          echo "usage: child-net block|unblock|status" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  options.${namespace}.roles.parent = {
    enable = mkEnableOption "Enable the parent role (control the child's devices' internet)";
    childDevices = mkOpt (types.listOf types.str) [
      "tv"
      "tv-wifi"
      "homebook"
      "ipad"
    ] "Child's device host names (keys into defaults.network.hosts) the parent can cut off";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = all (d: hasAttr d defaults.network.hosts) cfg.childDevices;
        message =
          "roles.parent.childDevices contains unknown host(s): "
          + concatStringsSep ", " (filter (d: !hasAttr d defaults.network.hosts) cfg.childDevices)
          + ". Valid hosts: "
          + concatStringsSep ", " (attrNames defaults.network.hosts);
      }
    ];

    # Generic router control primitive (`router-net`) lives here.
    ${namespace}.roles.router-manager = enabled;

    home.packages = [ child-net ];
  };
}
```

- [ ] **Step 2: Verify the module parses and the assertion fires on bad input**

Run: `just lint && just format modules/home/roles/parent/default.nix`
Expected: no lint/format errors.

The eval-time assertion is exercised in Task 5 (enabled on a real home). Sanity-check the assertion logic mentally: a `childDevices` entry not in `defaults.network.hosts` must make the build fail with the "unknown host(s)" message.

- [ ] **Step 3: Commit**

```bash
git add modules/home/roles/parent/default.nix
git commit -m "feat(parent): parent role with childDevices option and child-net wrapper"
```

---

## Task 4: Wire `roles.parent` into the parent's home

Enables the role on the family laptop the parent uses. `alexander@homebook` is the clear family context.

> **Decision point (adjustable):** This plan enables `roles.parent` on `alexander@homebook` only. If the parent also wants the command on `alexander@desktop` and/or `oleksandrsy@workbook`, add `roles.parent = enabled;` there too (workbook is darwin — the role has no Linux assertion, so it builds). Enabling it also pulls in `roles.router-manager` (hence `winbox4` + `router-net`) on `homebook`, which currently lacks it.

**Files:**
- Modify: `homes/x86_64-linux/alexander@homebook/default.nix`

- [ ] **Step 1: Enable the role**

In `homes/x86_64-linux/alexander@homebook/default.nix`, add `parent = enabled;` to the `roles` block:

```nix
    roles = {
      homebook = enabled;
      parent = enabled;
    };
```

- [ ] **Step 2: Format + commit**

```bash
just format homes/x86_64-linux/alexander@homebook/default.nix
git add homes/x86_64-linux/alexander@homebook/default.nix
git commit -m "feat(homebook): enable parent role for alexander"
```

---

## Task 5: Full validation (build, shellcheck, assertion, runtime)

**Files:** none (validation only)

- [ ] **Step 1: Repo-wide static checks**

Run: `just check`
Expected: `format-check` + `lint` pass (statix/deadnix/nixfmt clean).

- [ ] **Step 2: Build the parent's home (compiles the scripts → runs shellcheck)**

Run: `just build` on `homebook`, or:
```bash
nix build ".#homeConfigurations.\"alexander@homebook\".activationPackage" --no-link
```
Expected: builds successfully. A shell error in `router-net`/`child-net` would fail here via `writeShellApplication`'s shellcheck.

- [ ] **Step 3: Assertion negative test**

Temporarily set `roles.parent.childDevices = [ "tv" "nonesuch" ];` in `alexander@homebook`, rebuild.
Expected: build **fails** with `roles.parent.childDevices contains unknown host(s): nonesuch`. Revert the change afterward.

- [ ] **Step 4: Behavioral test of generated RouterOS commands (no live router)**

On a machine with the built home on PATH (or via `nix run`), use the `ROUTER_SSH` stub seam. The stub must be a single-word command (see Task 2 Step 2) — use `echo`:
```bash
ROUTER_SSH=echo router-net block tv
```
Expected output includes:
```
/ip firewall address-list remove [find where list=banned address=10.0.0.50]
/ip firewall address-list add list=banned address=10.0.0.50 comment=router-net
/ip firewall connection remove [find where src-address~"^10\.0\.0\.50:"]
```
And:
```bash
ROUTER_SSH=echo router-net block bogushost; echo "exit=$?"
```
Expected: `unknown host 'bogushost'` on stderr, `exit=1`.
And:
```bash
ROUTER_SSH=echo child-net block
```
Expected: emits the block script for all four child device IPs (10.0.0.50, .51, .63, .70).

- [ ] **Step 5: Live router smoke test (manual, requires `router` SSH alias)**

On the parent's machine with the `router` alias configured:
- `child-net status` → prints an empty `banned` list.
- `child-net block` → the four child IPs appear in `banned`; an in-progress TV/iPad stream drops within seconds; a fresh device cannot reach the internet but can still reach the local server; `child-net status` lists the four devices.
- `child-net unblock` → devices removed from `banned`; internet restored.
- `router-net block server` then `router-net unblock server` → proves the generic primitive works for an arbitrary host.
- Idempotency: run `child-net block` twice → no duplicate entries in `banned`.

- [ ] **Step 6: Final commit (if any validation fixups were needed)**

```bash
git add -A
git commit -m "test(parent): validate build, assertion, and generated router commands"
```

---

## Notes & Skills

- Use @superpowers:verification-before-completion before claiming done — run the actual commands above and confirm output.
- Use @superpowers:finishing-a-development-branch to decide merge/PR once validation passes.
- Commit signing: this repo signs via SSH; a non-interactive agent may need to commit unsigned then re-sign the branch before push (see repo memory).
