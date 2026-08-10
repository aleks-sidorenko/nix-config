# Design: parent role — on-demand child internet control via router

- **Date**: 2026-07-20
- **Status**: Draft (pending spec-review + user approval)
- **Scope**: Give a parent a one-command way to cut off (and restore) the
  child's internet access across all the child's devices (TV, iPad, homebook)
  by toggling their membership in the router's `banned` address-list over SSH.
  Split into a **generic** host on/off primitive in `roles.router` and a
  **policy** layer in a new `roles.parent` that targets the child's devices.

## 1. Goals

1. **On-demand block.** A parent runs `child-net block` and the child's devices
   (`tv`, `tv-wifi`, `homebook`, `ipad`) immediately lose public-internet
   access — including any TV/iPad stream already playing. `child-net unblock`
   restores it. `child-net status` shows the current state.
2. **Separation of concerns.** `roles.router` provides a *generic,
   host-agnostic* primitive (`router-net block|unblock|status <host|ip>…`) that
   knows nothing about "child" or "parent". `roles.parent` is the *policy* layer
   that wires the child's device list into `child-net`.
3. **Declarative, single source of truth.** Host name→IP resolution comes from
   the existing `defaults.network.hosts` map — no IPs duplicated in scripts. The
   child device set lives as an overridable option on `roles.parent`.
4. **Immediate effect.** Blocking also flushes the devices' live connection
   tracking so established streams drop at once, not just new connections.

## 2. Non-goals

- No time-based scheduling, per-app/content filtering, or DNS-level blocking
  (YAGNI — this is a manual on/off switch; layer scheduling later if wanted).
- No new router-side firewall *rules*: the existing `forward_drop_banned_external`
  rule is reused untouched. The only runtime mutation is address-list membership.
- No darwin/home-independent CLI: the commands are installed into the parent's
  home via home-manager and run from the parent's machine.
- No management of the `router` SSH alias / key auth (assumed present, see §6).

## 3. Background — current state

- **Router IaC** `infra/router/default.nix` (terranix via `nix-routeros`):
  - Declares `firewall.addressLists.banned` seeded with **four hosts** today
    (`tv`, `tv-wifi`, `homebook`, `ipad`) — i.e. these are *permanently* blocked
    at every `just router-apply`.
  - Declares one filter rule `forward_drop_banned_external`: `action=drop`,
    `chain=forward`, `out_interface_list=WAN`, `src_address_list=banned` — drops
    WAN-bound traffic from anything in the `banned` list.
  - `imports.nix:317` note: "address-list will be created fresh by terraform";
    `imports.nix:373`: the drop rule is "created fresh by terraform" (not
    imported from existing router state).
  - Applied out-of-band via `just router-apply` (`nix run .#router.apply`); state
    is OpenTofu-encrypted at `infra/router/terraform.tfstate` and committed.
  - Existing `backup` script (`default.nix`) already SSHes to the router via the
    `router` alias (`ssh router …`, `scp router:…`) — the auth path this design
    reuses.
- **Known hosts** `lib/defaults/default.nix` → `defaults.network.hosts`: a
  name→IP map (`tv=10.0.0.50`, `tv-wifi=10.0.0.51`, `homebook=10.0.0.63`,
  `ipad=10.0.0.70`, plus router/server/etc.). This is the single source of truth
  for addresses and is **not** changed by this design.
- **Home roles** `modules/home/roles/`:
  - `router/default.nix` — currently just installs `pkgs.winbox4`.
  - `child/default.nix` — restricted child home (Minecraft-only GNOME). The new
    `parent` role is its policy counterpart.
- **Users module** distinguishes an `adult`/`child` **profile** (account group
  presets). The new `parent` **role** is a distinct concept (a capability to
  control the child's devices), deliberately *not* folded into the `adult`
  profile.

## 4. Design

### 4.1 Router baseline flip — `banned` starts empty

`infra/router/default.nix`: change

```nix
firewall.addressLists.banned = [
  defaults.network.hosts.tv
  defaults.network.hosts.tv-wifi
  defaults.network.hosts.homebook
  defaults.network.hosts.ipad
];
```

to

```nix
firewall.addressLists.banned = [ ];
```

The `forward_drop_banned_external` rule stays **exactly as-is** (always enabled).
Effect: the declared baseline is "nobody blocked"; an empty `banned` list means
the drop rule matches nothing. Runtime list membership becomes the sole control
knob, and blocking is *additive*. This matches the agreed semantics: internet
allowed by default, `child-net block` is the action that cuts it off.

**Accepted trade-off:** a manual `just router-apply` re-asserts the empty
declared baseline, clearing any active runtime block. Applies are infrequent and
manual; the reset-to-online behavior is acceptable (arguably desirable). This is
documented in the router README and in §5.

### 4.2 Generic primitive — `router-net` in `roles.router`

Add a `router-net` command (`pkgs.writeShellScriptBin`) to
`modules/home/roles/router/default.nix` alongside `winbox4`. It is fully
host-agnostic.

**Interface:**

```
router-net block   <host|ip> [<host|ip>…]   # add to banned list + flush live conns
router-net unblock <host|ip> [<host|ip>…]   # remove from banned list
router-net status                            # print current banned-list members
```

**Name resolution.** The `defaults.network.hosts` map is baked into the script at
build time as a name→IP lookup. An argument that is already a dotted IP is used
verbatim; otherwise it must be a known host name, else the script exits non-zero
listing the valid names. (No IPs are hardcoded in the shell — they come from
`defaults`, the single source of truth.)

**Router interaction** (over the `router` SSH alias, RouterOS CLI):
- `block` per IP (idempotent):
  - membership guard, then
    `/ip firewall address-list add list=banned address=<ip> comment="router-net"`
    only if not already present (`… print where list=banned address=<ip>`),
  - flush established connections so a playing stream drops immediately:
    `/ip firewall connection remove [find where src-address~"^<ip>:"]`.
- `unblock` per IP:
  `/ip firewall address-list remove [find where list=banned address=<ip>]`
  (no-op if absent).
- `status`: `/ip firewall address-list print where list=banned` (rendered as a
  readable name+IP list using the baked-in map).

**Error handling:** unknown host name → non-zero exit + valid-names hint; any SSH
/ RouterOS command failure → non-zero exit with the router's stderr surfaced;
`block`/`unblock` require ≥1 argument (usage on none).

The `list=banned` name couples this primitive to the terranix-declared list —
intentional: it reuses the one existing drop rule. Documented in the script's
help/comment so the coupling is discoverable.

### 4.3 Policy layer — new `roles.parent`

New module `modules/home/roles/parent/default.nix`, mirroring the shape of
`roles.child` / `roles.router`.

**Options** (`nix-config.roles.parent`):
- `enable` — `mkEnableOption`.
- `childDevices` — `mkOpt (listOf str)` defaulting to
  `[ "tv" "tv-wifi" "homebook" "ipad" ]`. Host **names** (keys into
  `defaults.network.hosts`), representing the child's devices this parent can cut
  off. Overridable per-home. Named `childDevices` (not `devices`) so ownership is
  explicit — these are the *child's* devices, controlled by the parent.

**Config** (`mkIf cfg.enable`):
- `assertion`: every entry of `childDevices` is a key in
  `defaults.network.hosts` (fail fast at eval with the offending name).
- Enables the generic infra: `nix-config.roles.router = enabled;`.
- Installs `child-net` (`pkgs.writeShellScriptBin`) — a thin wrapper that forwards
  to `router-net` with the configured device list baked in:
  - `child-net block`   → `router-net block   <childDevices…>`
  - `child-net unblock` → `router-net unblock <childDevices…>`
  - `child-net status`  → calls `router-net status` and post-filters its stdout
    to the child device set for a focused view (display-only, no router logic).

`child-net` contains **no** router logic of its own — all SSH/RouterOS behavior
lives in the generic `router-net`; `child-net`'s only added behavior is baking in
the device list and the status display filter. This keeps the policy layer
trivial and the primitive reusable.

**Platform note.** Unlike `roles.child` (which asserts `pkgs.stdenv.isLinux`),
`roles.parent` installs SSH client scripts meant to run from the parent's own
machine — which may be the darwin workbook. It therefore carries **no** Linux
assertion; do not copy one over by pattern-matching on `roles.child`.

### 4.4 Data flow

```
build time:   defaults.network.hosts ──▶ router-net (name→IP map)
              roles.parent.childDevices ──▶ child-net (device names)

runtime:      child-net block
                └▶ router-net block tv tv-wifi homebook ipad
                     └▶ ssh router:  address-list add … (×N, idempotent)
                                     connection remove … (×N, immediate cutoff)
```

## 5. Caveats (documented, accepted)

- **`router-apply` resets state.** A manual apply re-asserts the empty `banned`
  baseline and clears an active block. Accepted; noted in router README.
- **All-or-per-device via the shared list.** Both `router-net` (arbitrary hosts)
  and `child-net` (the child set) mutate the *same* `banned` list feeding the one
  drop rule. This is the intended reuse; there is no separate per-role rule.
- **SSH alias prerequisite.** Requires the `router` SSH alias with key auth in the
  operator's `~/.ssh/config` (already required by `router-backup`). Not created
  here; a missing alias surfaces as a clear SSH error.
- **Wi-Fi vs LAN.** The drop rule targets `out_interface_list=WAN` only — blocked
  devices keep LAN access (local server, Minecraft) and lose only public
  internet. This is the desired behavior ("can't watch/stream", can still reach
  local services).

## 6. Prerequisites

- `router` SSH alias resolvable with non-interactive key auth from the parent's
  machine (same as `router-backup`).
- Old API / SSH access to the MikroTik as already used by the router IaC.

## 7. Affected files

- `infra/router/default.nix` — `banned` list → `[ ]` (empty baseline).
- `infra/router/README.md` — note the runtime-vs-apply trade-off.
- `modules/home/roles/router/default.nix` — add generic `router-net`
  command (keep `winbox4`).
- `modules/home/roles/parent/default.nix` — **new**; `parent` role with
  `childDevices` option + `child-net` wrapper; enables `router`.

## 8. Verification

- `just check` + `just build` (evaluation, assertion for a bad `childDevices`
  entry fails as expected).
- On a home with `roles.parent.enable = true`:
  - `router-net status` / `child-net status` prints an empty banned list initially.
  - `child-net block` → the four devices appear in `banned`; a TV/iPad stream in
    progress drops within seconds (connection flush); a fresh device can't reach
    the internet but still reaches the local server.
  - `child-net unblock` → devices removed from `banned`; internet restored.
  - `router-net block <single-host>` / `unblock` works for an arbitrary host,
    proving the primitive is generic; unknown name errors with a hint.
  - Idempotency: running `block` twice does not create duplicate list entries.
```

