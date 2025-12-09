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

  publicKey = "id_ed25519.pub";
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Whether or not to enable ssh";

    publicKey = mkOption {
      type = str;
      default = "~/.ssh/${publicKey}";
      readOnly = true;
      description = "Path to the public SSH key";
    };
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {

        "*" = {
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

    home.file."${cfg.publicKey}".source = ./${publicKey};
  };
}
