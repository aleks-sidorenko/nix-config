{ den, ... }:
{
  den.aspects.roles.workstation.includes = [
    den.aspects.security.sops
    den.aspects.security.nix-access-tokens
    den.aspects.services.tailscale
    den.aspects.system.homebrew
    den.aspects.system.dock
    den.aspects.system.finder
    den.aspects.system.input
    den.aspects.system.power
    den.aspects.system.file-limits
    den.aspects.system.stylix
    den.aspects.security.sudo.touch-id
    den.aspects.cli.fish
    den.aspects.cli.starship
    den.aspects.cli.atuin
    den.aspects.cli.zellij
    den.aspects.cli.yazi
    den.aspects.cli.nvim
    den.aspects.cli.ghostty
    den.aspects.cli.bat
    den.aspects.cli.fzf
    den.aspects.cli.htop
    den.aspects.cli.utils
    den.aspects.cli.nix-index
  ];
}
