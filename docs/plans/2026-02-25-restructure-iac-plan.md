# Restructure IaC Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract router IaC from `packages/` to a new top-level `infra/` directory, consolidate split terraform modules, delete obsolete files, and wire the router derivation explicitly in `flake.nix`.

**Architecture:** Move `packages/router/` and `modules/terraform/routeros/` into `infra/router/`, update all path references (flake.nix, default.nix, .sops.yaml, justfile), and add explicit flake output for the router package since `infra/` is not snowfall-lib auto-discovered.

**Tech Stack:** Nix (snowfall-lib, terranix), OpenTofu, SOPS, just

**Design doc:** `docs/plans/2026-02-25-restructure-iac-design.md`

---

### Task 1: Delete obsolete `config.rsc`

**Files:**
- Delete: `config.rsc`

**Step 1: Delete the file**

```bash
git rm config.rsc
```

**Step 2: Commit**

```bash
git commit -m "chore: remove obsolete config.rsc (replaced by terranix)"
```

---

### Task 2: Create `infra/router/` and move files from `packages/router/`

**Files:**
- Create directory: `infra/router/`
- Move: `packages/router/default.nix` → `infra/router/default.nix`
- Move: `packages/router/hosts.nix` → `infra/router/hosts.nix`
- Move: `packages/router/imports.nix` → `infra/router/imports.nix`
- Move: `packages/router/secrets.yaml` → `infra/router/secrets.yaml`
- Move: `packages/router/terraform.tfstate` → `infra/router/terraform.tfstate`
- Move: `packages/router/encryption.tf` → `infra/router/encryption.tf`
- Do NOT move: `packages/router/.terraform/`, `packages/router/.terraform.lock.hcl`, `packages/router/config.tf.json`, `packages/router/terraform.tfstate.backup` — these are gitignored artifacts that will be regenerated on next `tofu init`
- Delete: `packages/router/` directory (after moving tracked files)

**Step 1: Create directory and move tracked files**

```bash
mkdir -p infra/router
git mv packages/router/default.nix infra/router/default.nix
git mv packages/router/hosts.nix infra/router/hosts.nix
git mv packages/router/imports.nix infra/router/imports.nix
git mv packages/router/secrets.yaml infra/router/secrets.yaml
git mv packages/router/terraform.tfstate infra/router/terraform.tfstate
git mv packages/router/encryption.tf infra/router/encryption.tf
```

**Step 2: Clean up leftover untracked files in packages/router/**

```bash
rm -rf packages/router/
```

**Step 3: Verify the move**

```bash
ls -la infra/router/
# Should show: default.nix, hosts.nix, imports.nix, secrets.yaml, terraform.tfstate, encryption.tf
```

**Step 4: Commit**

```bash
git commit -m "refactor: move packages/router/ to infra/router/"
```

---

### Task 3: Move `modules/terraform/routeros/` into `infra/router/modules/`

**Files:**
- Move: `modules/terraform/routeros/` → `infra/router/modules/`
- Delete: `modules/terraform/` (empty after move)

**Step 1: Move terraform modules**

```bash
git mv modules/terraform/routeros infra/router/modules
```

**Step 2: Remove empty parent directory**

`modules/terraform/` should now be empty. Git doesn't track empty directories, so it will disappear automatically. Verify:

```bash
ls modules/terraform/ 2>/dev/null || echo "Directory gone (expected)"
# If it still exists with files, investigate before deleting
```

**Step 3: Verify the move**

```bash
ls infra/router/modules/
# Should show: bridge, capsman, dhcp, dns, firewall, interfaces, misc, provider, system
```

**Step 4: Commit**

```bash
git commit -m "refactor: move modules/terraform/routeros/ to infra/router/modules/"
```

---

### Task 4: Update path references in `infra/router/default.nix`

**Files:**
- Modify: `infra/router/default.nix`

**Step 1: Update `terraformModulesPath`**

Change line 70:
```nix
# FROM:
terraformModulesPath = ../../modules/terraform/routeros;
# TO:
terraformModulesPath = ./modules;
```

**Step 2: Update `stateDir`**

Change line 72:
```nix
# FROM:
stateDir = "packages/router";
# TO:
stateDir = "infra/router";
```

**Step 3: Update `secretsFile`**

Change line 73:
```nix
# FROM:
secretsFile = "packages/router/secrets.yaml";
# TO:
secretsFile = "infra/router/secrets.yaml";
```

**Step 4: Commit**

```bash
git commit -m "refactor: update infra/router/default.nix path references"
```

---

### Task 5: Wire router derivation explicitly in `flake.nix`

**Files:**
- Modify: `flake.nix`

Since `packages/router/` was snowfall-lib auto-discovered as a package, and `infra/` is not auto-discovered, we need to add the router derivation to flake outputs manually.

**Step 1: Add the router package to flake outputs**

The `lib.mkFlake` call returns an attrset. We need to add the router package to the `packages` output for each system. The current `outputs-builder` already exists (line 258). Extend it to include the router package:

```nix
# In the lib.mkFlake { ... } block, change:
outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-tree; };

# TO:
outputs-builder =
  channels:
  let
    pkgs = channels.nixpkgs;
    system = pkgs.system;
  in
  {
    formatter = pkgs.nixfmt-tree;
    packages.router = import ./infra/router {
      inherit
        lib
        pkgs
        system
        ;
      namespace = "nix-config";
    };
  };
```

Note: The `import ./infra/router` call will invoke `infra/router/default.nix` which expects `{ lib, pkgs, system, namespace, ... }`. The `lib` here is the snowfall-lib extended lib from the `let` binding. The `namespace` must be passed explicitly since it's not auto-injected outside snowfall-lib's package discovery.

**Step 2: Verify the build**

```bash
nix run .#router -- | head -5
# Should show JSON output from router-show
```

If the above fails, check that the `lib` variable from the outer `let` block is accessible inside `outputs-builder`. If not, it may need to be `inputs.self.lib` or the import may need adjustment.

**Step 3: Commit**

```bash
git commit -m "feat(flake): wire infra/router as explicit package output"
```

---

### Task 6: Update `.sops.yaml` path regex

**Files:**
- Modify: `.sops.yaml`

**Step 1: Update the router secrets path**

Change line 51:
```yaml
# FROM:
  - path_regex: packages/router/secrets.ya?ml$
# TO:
  - path_regex: infra/router/secrets.ya?ml$
```

**Step 2: Verify SOPS can still decrypt**

```bash
sops -d --extract '["router-api-password"]' infra/router/secrets.yaml
# Should output the decrypted password (or fail gracefully if you don't have the key on this machine)
```

**Step 3: Commit**

```bash
git commit -m "chore: update .sops.yaml path for infra/router/secrets.yaml"
```

---

### Task 7: Update justfile references

**Files:**
- Modify: `justfile`

**Step 1: Update `router-secrets` command (line 340)**

```just
# FROM:
router-secrets:
    sops packages/router/secrets.yaml

# TO:
router-secrets:
    sops infra/router/secrets.yaml
```

**Step 2: Update `router-help` text (lines 355-360)**

Change all occurrences of `packages/router/` to `infra/router/`:

Line 355:
```
# FROM:
    @echo "  - SOPS secrets in packages/router/secrets.yaml:"
# TO:
    @echo "  - SOPS secrets in infra/router/secrets.yaml:"
```

Line 359:
```
# FROM:
    @echo "  - State is natively encrypted by OpenTofu (PBKDF2 + AES-GCM) at packages/router/terraform.tfstate"
# TO:
    @echo "  - State is natively encrypted by OpenTofu (PBKDF2 + AES-GCM) at infra/router/terraform.tfstate"
```

Line 360:
```
# FROM:
    @echo "  - Commit the updated state file after apply: git add packages/router/terraform.tfstate && git commit"
# TO:
    @echo "  - Commit the updated state file after apply: git add infra/router/terraform.tfstate && git commit"
```

**Step 3: Commit**

```bash
git commit -m "chore: update justfile router paths to infra/router/"
```

---

### Task 8: Update CLAUDE.md references

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Check for any `packages/router` or `modules/terraform` references in CLAUDE.md**

Search for and update any references. The CLAUDE.md currently doesn't directly reference `packages/router/` paths, but the "Architecture" and "Custom Packages" sections mention the router package. Update relevant sections to reflect the new `infra/` location.

**Step 2: Commit**

```bash
git commit -m "docs: update CLAUDE.md for infra/ restructure"
```

---

### Task 9: Final verification

**Step 1: Check flake evaluates**

```bash
nix flake check 2>&1 | head -20
```

**Step 2: Verify router commands work**

```bash
just router-show 2>&1 | head -5
# Should show terraform JSON

just router-help
# Should show updated paths
```

**Step 3: Verify directory structure is clean**

```bash
ls packages/
# Should show: install, nvim, wallpapers (NO router)

ls modules/
# Should show: darwin, home, nixos (NO terraform)

ls infra/router/
# Should show: default.nix, encryption.tf, hosts.nix, imports.nix, modules, secrets.yaml, terraform.tfstate

ls infra/router/modules/
# Should show: bridge, capsman, dhcp, dns, firewall, interfaces, misc, provider, system
```

**Step 4: If all checks pass, squash or leave as-is**

The individual commits tell a clean story. If preferred, they can be squashed into a single commit for the PR.
