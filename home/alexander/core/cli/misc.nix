{pkgs, ...}: {
  
  home.packages = with pkgs; [
    comma # Install and run programs by sticking a , before them
    curl
    distrobox # Nice escape hatch, integrates docker images with my environment

    bc # Calculator
    bottom # System viewer
    btop # Replacement for htop/nmon
    ncdu # TUI disk usage
    eza # Better ls
    ripgrep # Better grep
    fd # Better find
    httpie # Better curl
    diffsitter # Better diff
    jq # JSON pretty printer and manipulator

    timer # To help with my ADHD paralysis
    
    alejandra # Nix formatter
    nixfmt-rfc-style
    nvd # Differ
    nix-diff # Differ, more detailed
    nix-output-monitor
    nixd # Nix LSP
    nh # Nice wrapper for NixOS and HM
    p7zip
    unzip
    wget
    zip
  ];
}
