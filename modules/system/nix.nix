{ lib, ... }:
{
  den.aspects.system.nix = {
    os =
      { pkgs, ... }:
      {
        nix = {
          # Latest, like the generations before it, so booting between them
          # never downgrades the daemon over a store a newer one has used.
          package = pkgs.nixVersions.latest;
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
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
        };
      };

    nixos = {
      nix = {
        # corrupts the store on darwin, so NixOS only
        settings = {
          auto-optimise-store = true;
          trusted-users = [
            "root"
            "@wheel"
          ];
          use-xdg-base-directories = true;
        };
      };

      # nix.gc would prune by age alone; nh keeps the last generations whatever
      # their age, so a fallback generation survives.
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d --keep 5";
        };
      };
    };

    darwin =
      { pkgs, ... }:
      {
        # Admins are `admin` on macOS; `wheel` holds only root.
        nix.settings.trusted-users = [
          "root"
          "@admin"
        ];

        # nix-darwin has no programs.nh; same retention as NixOS, run weekly.
        environment.systemPackages = [ pkgs.nh ];
        launchd.daemons.nh-clean.serviceConfig = {
          ProgramArguments = [
            (lib.getExe pkgs.nh)
            "clean"
            "all"
            "--keep-since"
            "7d"
            "--keep"
            "5"
          ];
          StartCalendarInterval = [
            {
              Weekday = 0;
              Hour = 3;
              Minute = 0;
            }
          ];
        };
      };
  };
}
