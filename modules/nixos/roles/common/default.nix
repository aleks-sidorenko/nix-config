{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = {
    enable = mkEnableOption "Enable common configuration";
  };

  config = lib.mkIf cfg.enable {

    ${namespace} = {

      # Reuse the bare base (ssh, nix, locale, networking, fish) instead of
      # duplicating it here.
      roles.minimal = enabled;

      security = {
        sops.enable = true;
      };

      cli = {
        # General Nix ergonomics, useful on any managed host.
        tools = {
          nh.enable = true;
          nix-ld.enable = true;
        };
      };

      system = {
        nix.githubAuth = true;
        boot.enable = true;
        fs.enable = true;
      };

      disks = {
        impermanence.enable = true;
      };

    };

  };
}
