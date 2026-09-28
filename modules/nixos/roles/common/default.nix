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

      # Host identity lives on the tailnet, so membership is part of the base
      # system rather than a property of any one role. mkDefault so a host can
      # opt out.
      services.networking.tailscale = {
        enable = mkDefault true;
        # Joining is unattended everywhere: a host that cannot decrypt the key
        # fails activation, which is why this is safe only while every host
        # with this role is a recipient of its platform's secrets file.
        authKeyFromSecret = mkDefault true;
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
