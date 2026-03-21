{
  config,
  lib,
  namespace,
  inputs,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.nix;
  sopsEnabled = config.${namespace}.security.sops.enable;
in
{
  options.${namespace}.system.nix = with types; {
    enable = mkBoolOpt false "Whether or not to manage nix configuration";
    githubAuth = mkBoolOpt false "Whether to enable GitHub authentication for Nix";
  };

  config = mkIf cfg.enable {
    # Configure SOPS secret for GitHub token
    sops.secrets."system-github-token" = mkIf (sopsEnabled && cfg.githubAuth) {
      sopsFile = ../../secrets.yaml;
      mode = "0440";
      restartUnits = [ "nix-daemon.service" ];
    };

    nix = {
      settings = {
        trusted-users = [
          "@wheel"
          "root"
        ];
        # Optimize the Nix store on each build
        auto-optimise-store = lib.mkDefault true;
        use-xdg-base-directories = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        warn-dirty = false;
        system-features = [
          "big-parallel"
        ];
        # Configure binary caches for faster package downloads
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

      # Configure GitHub access token for Nix
      extraOptions = mkIf (sopsEnabled && cfg.githubAuth) ''
        !include ${config.sops.secrets."system-github-token".path}
      '';

      # Enable garbage collection
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
        persistent = true;
        randomizedDelaySec = "1hour";
      };

      # Configure NixOS to use the same software channel as Flakes
      registry.nixpkgs.flake = inputs.nixpkgs;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      # flake-utils-plus
      generateRegistryFromInputs = true;
      generateNixPathFromInputs = true;
      linkInputs = true;
    };
  };
}
