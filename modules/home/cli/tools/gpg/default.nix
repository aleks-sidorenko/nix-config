{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.tools.gpg;
in {
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
      sshKeys = ["D528D50F4E9F031AACB1F7A9833E49C848D6C90"]; # FIXME
      pinentryPackage = pkgs.pinentry-gnome3;
    };

    programs = {
      gpg = {
        enable = true;
        #homedir = "${config.xdg.dataHome}/gnupg";
      };
    };    
  };
}
