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
      default = [ (builtins.readFile ./ssh-key-id) ];
      description = "List of GPG key IDs that can be used as SSH keys";
    };
  };

  config = mkIf cfg.enable {

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      sshKeys = cfg.sshKeys;
      defaultCacheTtl = 1800;
      defaultCacheTtlSsh = 1800;
      pinentryPackage = if config.gtk.enable then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;
      extraConfig = ''
        allow-preset-passphrase
        ttyname $GPG_TTY
      '';
    };

    home.packages =
      with pkgs;
      [
        gnupg
      ]
      ++ lib.optionals config.gtk.enable [ gcr ];

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
        matchBlocks."*".addKeysToAgent = mkForce "no"; # Let GPG agent handle the keys, don't add keys to the agent automatically
      };
      keychain.enable = mkForce false;

    };

    systemd.user.tmpfiles.rules = [
      "L+ %h/.gnupg-sockets - - - - /run/user/%U/gnupg"
    ];

    home.sessionVariables = {
      SSH_AUTH_SOCK = "$(gpgconf --list-dirs agent-ssh-socket)";
      GPG_TTY = "$(tty)";
    };

    # Ensure GPG agent is updated with the current TTY at shell start
    programs.bash.initExtra = gpgInitScript;
    programs.zsh.initExtra = gpgInitScript;
    programs.fish.interactiveShellInit = gpgInitScript;

  };
}
