# GitHub Token for Nix Authentication

## Quick Setup

### 1. Create GitHub Token
- Go to: https://github.com/settings/tokens
- Generate new token (classic)
- Required scopes: `repo`, `read:packages`

### 2. Add Token to Secrets

```bash
sops modules/nixos/secrets.yaml
```

Add this line:

```yaml
nix-github-token: |
  access-tokens = github.com=ghp_YOUR_TOKEN_HERE
```

### 3. Rebuild System

```bash
sudo nixos-rebuild switch --flake .#desktop
```

## What Was Configured

- Modified `modules/nixos/system/nix/default.nix`:
  - Added `githubAuth` option
  - Configured SOPS secret `nix-github-token`
  - Set up Nix extraOptions to use the token

- Modified `modules/nixos/roles/common/default.nix`:
  - Enabled `githubAuth = true` for all systems

## Verification

After rebuild, test with:

```bash
# Check secret file exists
ls -la /run/secrets/nix-github-token

# Test GitHub API access
nix flake metadata github:nixos/nixpkgs
```

## Token Format

The secret must be in this exact format:

```
access-tokens = github.com=<token>
```

This is automatically included in Nix configuration via `nix.extraOptions`.

