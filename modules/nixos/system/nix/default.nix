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
in
{
  options.${namespace}.system.nix = with types; {
    enable = mkBoolOpt false "Whether or not to manage nix configuration";
    retention = mkOption {
      description = "How long to retain NixOS generations. Defaults to two weeks.";
      type = str;
      default = "14d";
    };
  };

  config = mkIf cfg.enable {
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
          "kvm"
          "big-parallel"
          "nixos-test"
        ];

      };

      # Enable garbage collection
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than ${cfg.retention}";
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
