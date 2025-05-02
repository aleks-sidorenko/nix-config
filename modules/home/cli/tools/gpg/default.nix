{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.gpg;
in
{
  options.${namespace}.cli.tools.gpg = with types; {
    enable = mkBoolOpt false "Whether or not to enable gpg";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.seahorse
    ];

    services.gnome-keyring.enable = true;

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      sshKeys = [ "D475CFA955B1C3902A57492EC78CD48FE9404C90" ];
      pinentryPackage = pkgs.pinentry-gnome3;
    };

    programs = {
      gpg = {
        enable = true;
      };
    };
  };
}
