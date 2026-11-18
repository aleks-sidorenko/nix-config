{ lib, ... }:
{
  den.aspects.system.homebrew.darwin = {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = false;
        # Homebrew 6 removed `brew bundle --cleanup`, and any value other than
        # "none" makes nix-darwin pass that now-fatal switch on activation.
        cleanup = "none";
      };
    };

    # After the nix profiles (default order), before the system dirs (1200):
    # a leftover formula must never shadow the nix package of the same name.
    environment.systemPath = lib.mkOrder 1100 [ "/opt/homebrew/bin" ];
  };
}
