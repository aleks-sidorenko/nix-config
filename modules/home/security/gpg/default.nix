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
  identity = config.${namespace}.security.identity;

  gpgInitScript = ''
    gpg-connect-agent updatestartuptty /bye >/dev/null
  '';
in
{
  options.${namespace}.security.gpg = with types; {
    enable = mkBoolOpt false "Whether or not to enable gpg";
    cacheTtl = mkOption {
      type = types.int;
      default = 86400;
      description = "Cache TTL for GPG and SSH keys in seconds (default: 24 hours)";
    };
    publicKeys = mkOption {
      type = types.listOf types.str;
      default = lib.optional (identity.gpgPublicKeyFile != null) (toString identity.gpgPublicKeyFile);
      description = "A list of paths to public key files to import (defaults to the active identity's).";
    };
    sshKeys = mkOption {
      type = types.listOf types.str;
      default = lib.optional (identity.gpgKeyId != null) identity.gpgKeyId;
      description = "List of GPG key IDs usable as SSH keys (defaults to the active identity's).";
    };
  };

  config = mkIf cfg.enable {

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      enableExtraSocket = true;
      inherit (cfg) sshKeys;
      defaultCacheTtl = cfg.cacheTtl;
      defaultCacheTtlSsh = cfg.cacheTtl;
      maxCacheTtl = cfg.cacheTtl;
      maxCacheTtlSsh = cfg.cacheTtl;
      pinentry.package = pkgs.pinentry-curses;
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

    systemd.user.tmpfiles.rules = mkIf pkgs.stdenv.isLinux [
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
