{ den, ... }:
{
  den.aspects.roles.workstation.includes = [
    den.aspects.security.sops
    den.aspects.security.nix-access-tokens
    den.aspects.services.tailscale
    den.aspects.system.networking
    den.aspects.system.homebrew
    den.aspects.system.dock
    den.aspects.system.finder
    den.aspects.system.input
    den.aspects.system.power
    den.aspects.system.file-limits
    den.aspects.security.sudo.touch-id
  ];
}
