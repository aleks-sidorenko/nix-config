{
  description = "Alexander's Nix/NixOS Config";

  inputs = {
    # Stable channel - NixOS 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Unstable channel for specific packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter-modules = {
      url = "github:numtide/nixos-facter-modules";

    };

    nixos-anywhere = {
      url = "github:numtide/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comma = {
      url = "github:nix-community/comma";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland

    hypr-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprcursor = {
      url = "github:hyprwm/Hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyprland = {
      url = "github:hyprland-community/pyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Homelab

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Styling

    catppuccin-obs = {
      url = "github:catppuccin/obs";
      flake = false;
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Terminal

    zjstatus = {
      url = "github:dj95/zjstatus";
    };

    # Neovim

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };

    plugins-cmp-dbee = {
      url = "github:MattiasMTS/cmp-dbee";
      flake = false;
    };

    plugins-gx-nvim = {
      url = "github:chrishrb/gx.nvim";
      flake = false;
    };

    plugins-maximize-nvim = {
      url = "github:declancm/maximize.nvim";
      flake = false;
    };

    # firefox
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Darwin (macOS)
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          metadata = "nix-config";
          namespace = "nix-config";
          meta = {
            name = "nix-config";
            title = "Alexander's Nix Flake";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };

      systems = {
        modules.nixos = with inputs; [
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
        ];
        modules.darwin = with inputs; [
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops
        ];
        hosts = {
          # hosts specific modules
          desktop = {
            modules = with inputs.nixos-hardware.nixosModules; [
              common-cpu-intel
            ];
          };

          minimal = {
            modules = with inputs; [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ];
          };
        };
      };

      overlays = with inputs; [
        nixgl.overlay
        nur.overlays.default
        # Make unstable packages available as pkgs.unstable
        (final: prev: {
          unstable = import nixpkgs-unstable {
            system = final.system;
            config.allowUnfree = true;
          };
        })
      ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks = builtins.mapAttrs (
        system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy
      ) inputs.deploy-rs.lib;

      outputs-builder =
        channels:
        let
          pkgs = channels.nixpkgs;
          system = pkgs.system;
          # Construct system-lib matching what snowfall-lib passes to packages:
          # base nixpkgs.lib extended with user lib under the namespace.
          # The outer `lib` (from mkLib) has user lib functions at the top level;
          # packages expect them under `lib.nix-config`.
          router-lib = pkgs.lib // {
            "nix-config" = lib;
            snowfall = lib.snowfall;
          };
        in
        {
          formatter = pkgs.nixfmt-tree;
          # TODO: could this be generic? infra/**/name1 should be imported as package
          packages.router = import ./infra/router {
            lib = router-lib;
            inherit pkgs system;
            namespace = "nix-config";
          };
        };
    };
}
