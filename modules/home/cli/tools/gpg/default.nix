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
    publicKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "A list of public keys to import.";
    };
  };

  config = mkIf cfg.enable {
    
    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      sshKeys = [ "D475CFA955B1C3902A57492EC78CD48FE9404C90" ];
      pinentry.package =
        if config.gtk.enable
        then pkgs.pinentry-gnome3
        else pkgs.pinentry-tty;
    };

    home.packages = lib.optional config.gtk.enable pkgs.gcr;

    programs = {
      
      gpg = {
        enable = true;
        settings = {
          trust-model = "tofu+pgp";
        };
        publicKeys = [
        {
          source = ./pgp.asc;
          trust = "ultimate";
        }
      ];
          

      };
      ssh = {
        addKeysToAgent = "no";
        startAgent = false;
      };
    };

  
  
    systemd.user.tmpfiles.rules = [
      "L+ %h/.gnupg-sockets - - - - /run/user/%U/gnupg"
    ];

  
    # Ensure TTY and agent work in shells
    environment.shellInit = ''
      export GPG_TTY=$(tty)
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
      gpg-connect-agent updatestartuptty /bye >/dev/null
    '';

  };
}
