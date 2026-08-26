{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.ssh;
  identity = resolveIdentity config;

  relativePublicKeyPath = ".ssh/id_ed25519.pub";
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Whether or not to enable ssh";

    user = mkStringOpt lib.${namespace}.defaults.user "Username to use when connecting to remote hosts";

    publicKeyPath = mkOption {
      type = str;
      default =
        if identity.sshPublicKeyFile != null then
          "${config.home.homeDirectory}/${relativePublicKeyPath}"
        else
          "";
      readOnly = true;
      description = "Path to the public SSH key (empty when the identity has no key).";
    };

    publicKey = mkOption {
      type = str;
      default = if identity.sshPublicKey != null then identity.sshPublicKey else "";
      readOnly = true;
      description = "Content of the public SSH key (empty when the identity has no key).";
    };
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      # Source a user-writable file first so throwaway host aliases (test VMs,
      # un-reserved hosts during bootstrap) can be added without touching this
      # nix-managed, read-only config. First match wins, so these override "*".
      includes = [ "config.local" ];

      matchBlocks = {

        "*" = {
          inherit (cfg) user;
          addKeysToAgent = "confirm"; # Let GPG agent handle the keys
        };
      };

      extraConfig = ''
        # Use GPG agent for SSH
        IdentityAgent "$SSH_AUTH_SOCK"

        setEnv TERM="${config.${namespace}.cli.terminals.default.sshTerm}"
        setEnv SHELL="${config.${namespace}.cli.shells.default.name}"

      '';
    };

    home.file = mkIf (identity.sshPublicKeyFile != null) {
      "${relativePublicKeyPath}".source = identity.sshPublicKeyFile;
    };
  };
}
