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

    extraHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            hostname = lib.mkOption {
              type = lib.types.str;
              description = "The hostname or IP address of the SSH host.";
            };
            identityFile = lib.mkOption {
              type = lib.types.str;
              default = "~/${sshDir}/${keyName}";
              description = "The path to the identity file for the SSH host.";
            };
          };
        }
      );
      default = { };
      description = "A set of extra SSH hosts.";
      example = literalExample ''
        {
          "gitlab-personal" = {
            hostname = "gitlab.com";
            identityFile = "~/${sshDir}/${keyName}";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      # Let GPG agent handle the keys
      addKeysToAgent = "confirm";
      matchBlocks = cfg.extraHosts;
      extraConfig = ''
        # Use GPG agent for SSH
        IdentityAgent "$SSH_AUTH_SOCK"
      '';
    };
    
    home.file.".ssh/${publicKey}".source = ./${publicKey};
  };
}
