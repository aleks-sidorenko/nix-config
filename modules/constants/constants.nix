{
  config,
  lib,
  options,
  ...
}:
let
  hmUser = {
    home-manager.users.hm-test.home.stateVersion = "26.05";
  };
  nixosHost =
    extra:
    config.builders.nixos "x86_64-linux" {
      imports = [
        hmUser
        extra
      ];
      system.stateVersion = "26.05";
      users.users.hm-test.isNormalUser = true;
    };
  nixos = nixosHost { };
  overridden = nixosHost { constants.locale.timeZone = "UTC"; };
  darwin = config.builders.darwin "aarch64-darwin" {
    system.stateVersion = 5;
  };
  top = config.constants;
in
{
  options.constants = lib.mkOption {
    type = lib.types.submodule ./_options.nix;
    description = "Shared facts, set once and mirrored read-only into every class.";
  };

  config = {
    # The value comes only from `default`, so any definition in a host is a
    # second one and `readOnly` rejects it.
    flake.modules.generic.constants = {
      options.constants = lib.mkOption {
        type = lib.types.submodule ./_options.nix;
        readOnly = true;
        default = top;
        description = "Read-only mirror of the flake-level `constants`.";
      };
    };

    plumbing = {
      nixos = [ config.flake.modules.generic.constants ];
      darwin = [ config.flake.modules.generic.constants ];
      homeManager = [ config.flake.modules.generic.constants ];
    };

    evalTests = {
      constants-owner = {
        expr = config.constants.owner;
        expected = "alexander";
      };
      constants-locales-in-nixos = {
        expr = nixos.config.constants.locale.locales;
        expected = [
          "en_US.UTF-8"
          "uk_UA.UTF-8"
          "ru_RU.UTF-8"
        ];
      };
      constants-tailnet = {
        expr = config.constants.network.domains.tailnet;
        expected = "colobus-bramble.ts.net";
      };
      constants-top = {
        expr = config.constants.locale.timeZone;
        expected = "Europe/Kyiv";
      };
      constants-in-nixos = {
        expr = nixos.config.constants.locale.timeZone;
        expected = "Europe/Kyiv";
      };
      constants-in-darwin = {
        expr = darwin.config.constants.locale.timeZone;
        expected = "Europe/Kyiv";
      };
      constants-in-home = {
        expr = nixos.config.home-manager.users.hm-test.constants.locale.timeZone;
        expected = "Europe/Kyiv";
      };
      constants-override-fails = {
        expr =
          (builtins.tryEval (builtins.deepSeq overridden.config.constants overridden.config.constants))
          .success;
        expected = false;
      };
      constants-type-checked = {
        expr =
          (builtins.tryEval
            (lib.evalModules {
              modules = [
                ./_options.nix
                { locale.timeZone = 1; }
              ];
            }).config.locale.timeZone
          ).success;
        expected = false;
      };
      import-tree-skips-underscore = {
        expr = options ? locale;
        expected = false;
      };
    };
  };
}
