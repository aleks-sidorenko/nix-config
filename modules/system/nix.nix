{
  den.aspects.system.nix = {
    os = {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "@wheel"
          ];
          use-xdg-base-directories = true;
          warn-dirty = false;
          substituters = [
            "https://cache.nixos.org/"
            "https://nix-community.cachix.org"
            "https://cache.numtide.com"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          ];
        };
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
      };
    };

    nixos.nix = {
      # corrupts the store on darwin, so NixOS only
      settings.auto-optimise-store = true;
      gc = {
        dates = "weekly";
        persistent = true;
        randomizedDelaySec = "1hour";
      };
    };
  };
}
