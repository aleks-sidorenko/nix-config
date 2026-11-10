{ config, lib, ... }:
let
  core = config.builders.nixos "x86_64-linux" {
    imports = [ config.flake.modules.nixos.system-core ];
    system.stateVersion = "26.05";
  };
  c = core.config;
in
{
  flake.modules.nixos.system-core = {
    imports = with config.flake.modules.nixos; [
      nix
      locale
      networking
      fish
      ssh
    ];
  };

  evalTests = {
    system-core-no-root-login = {
      expr = c.services.openssh.settings.PermitRootLogin;
      expected = "no";
    };
    system-core-no-passwords = {
      expr = c.services.openssh.settings.PasswordAuthentication;
      expected = false;
    };
    system-core-fish = {
      expr = lib.hasPrefix "fish" c.users.defaultUserShell.name;
      expected = true;
    };
    system-core-root-bash = {
      expr = lib.hasPrefix "bash" c.users.users.root.shell.name;
      expected = true;
    };
    system-core-flakes = {
      expr = builtins.elem "flakes" c.nix.settings.experimental-features;
      expected = true;
    };
    system-core-substituters = {
      expr = lib.take 3 c.nix.settings.substituters;
      expected = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://cache.numtide.com"
      ];
    };
    system-core-registry = {
      expr = c.nix.registry ? nixpkgs;
      expected = true;
    };
    system-core-timezone = {
      expr = c.time.timeZone;
      expected = "Europe/Kyiv";
    };
    system-core-keymap = {
      expr = c.console.keyMap;
      expected = "us";
    };
    system-core-xkb = {
      expr = c.services.xserver.xkb.layout;
      expected = "us,ua,ru";
    };
    system-core-locale-native = {
      expr = c.i18n.extraLocaleSettings.LC_TIME;
      expected = "uk_UA.UTF-8";
    };
    system-core-networkmanager = {
      expr = c.networking.networkmanager.enable;
      expected = true;
    };
    system-core-search = {
      expr = c.networking.search;
      expected = [
        "colobus-bramble.ts.net"
        "lan"
      ];
    };
    system-core-ssh-keys-empty = {
      expr = c.users.users.root.openssh.authorizedKeys.keys;
      expected = [ ];
    };
  };
}
