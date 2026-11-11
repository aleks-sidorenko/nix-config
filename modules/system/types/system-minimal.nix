{ config, lib, ... }:
let
  core = config.builders.testNixos config.flake.modules.nixos.system-minimal;
  c = core.config;
in
{
  flake.modules.nixos.system-minimal = {
    imports = with config.flake.modules.nixos; [
      nix
      locale
      networking
      fish
      ssh
    ];
  };

  evalTests = {
    system-minimal-no-root-login = {
      expr = c.services.openssh.settings.PermitRootLogin;
      expected = "no";
    };
    system-minimal-no-passwords = {
      expr = c.services.openssh.settings.PasswordAuthentication;
      expected = false;
    };
    system-minimal-fish = {
      expr = lib.hasPrefix "fish" c.users.defaultUserShell.name;
      expected = true;
    };
    system-minimal-root-bash = {
      expr = lib.hasPrefix "bash" c.users.users.root.shell.name;
      expected = true;
    };
    system-minimal-flakes = {
      expr = builtins.elem "flakes" c.nix.settings.experimental-features;
      expected = true;
    };
    system-minimal-substituters = {
      expr = lib.take 3 c.nix.settings.substituters;
      expected = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://cache.numtide.com"
      ];
    };
    system-minimal-registry = {
      expr = c.nix.registry ? nixpkgs;
      expected = true;
    };
    system-minimal-timezone = {
      expr = c.time.timeZone;
      expected = "Europe/Kyiv";
    };
    system-minimal-keymap = {
      expr = c.console.keyMap;
      expected = "us";
    };
    system-minimal-xkb = {
      expr = c.services.xserver.xkb.layout;
      expected = "us,ua,ru";
    };
    system-minimal-locale-native = {
      expr = c.i18n.extraLocaleSettings.LC_TIME;
      expected = "uk_UA.UTF-8";
    };
    system-minimal-networkmanager = {
      expr = c.networking.networkmanager.enable;
      expected = true;
    };
    system-minimal-search = {
      expr = c.networking.search;
      expected = [
        "colobus-bramble.ts.net"
        "lan"
      ];
    };
    system-minimal-ssh-keys-empty = {
      expr = c.users.users.root.openssh.authorizedKeys.keys;
      expected = [ ];
    };
  };
}
