{
  # Lets prebuilt dynamically linked binaries (editor servers, vendor tools) run.
  den.aspects.system.nix-ld.nixos.programs.nix-ld.enable = true;
}
