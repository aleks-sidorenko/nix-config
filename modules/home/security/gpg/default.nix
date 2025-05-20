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
  cfg = config.${namespace}.security.gpg;

  gpgInitScript = ''
    gpg-connect-agent updatestartuptty /bye >/dev/null
  '';
in
{
  options.${namespace}.security.gpg = with types; {
    enable = mkBoolOpt false "Whether or not to enable gpg";
    publicKeys = mkOption {
      type = types.listOf types.str;
      default = [ (toString ./gpg.asc) ];
      description = "A list of paths to public key files to import";
    };
    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [ (lib.fileContents ./ssh-key-id) ];
      description = "List of GPG key IDs that can be used as SSH keys";
    };
  };

  config = mkIf cfg.enable {

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      sshKeys = cfg.sshKeys;
      pinentryPackage = if config.gtk.enable then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;
    };

    home.packages = lib.optional config.gtk.enable pkgs.gcr;

    programs = {

      gpg = {
        enable = true;
        settings = {
          trust-model = "tofu+pgp";
        };
        publicKeys = map (path: {
          source = path;
          trust = "ultimate";
        }) cfg.publicKeys;

      };

      ssh = {
        addKeysToAgent = mkForce "no";
      };
      keychain.enable = mkForce false;

    };

    systemd.user.tmpfiles.rules = [
      "L+ %h/.gnupg-sockets - - - - /run/user/%U/gnupg"
    ];

    home.sessionVariables = {
      SSH_AUTH_SOCK = "$(gpgconf --list-dirs agent-ssh-socket)";
    };

    programs.bash.initExtra = gpgInitScript;
    programs.zsh.initExtra = gpgInitScript;
    programs.fish.interactiveShellInit = gpgInitScript;

  };
}
