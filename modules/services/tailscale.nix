{
  config,
  den,
  lib,
  ...
}:
let
  inherit (config.installTests) perTestedHost;

  autoconnect = system: system.config.systemd.services.tailscaled-autoconnect.enable;
in
{
  den.aspects.services.tailscale = {
    persist.directories = [ "/var/lib/tailscale" ];
    installChecks = [ ''machine.succeed("systemctl is-active tailscaled.service")'' ];

    # No default: the join key is an OAuth client secret, which registers only
    # a tagged node.
    settings.tags = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      description = "ACL tags the host advertises when it joins the tailnet.";
    };

    nixos =
      { config, host, ... }:
      {
        # Joining is unattended: a host that can't decrypt the key fails
        # activation, so every host importing this must be a recipient of its
        # secrets file.
        sops.secrets."system-tailscale-auth-key" = { };

        services.tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.sops.secrets."system-tailscale-auth-key".path;
          # Required for OAuth client secrets used as auth keys; a plain,
          # already-approved key ignores it.
          authKeyParameters.preauthorized = true;
          extraUpFlags = [
            "--advertise-tags=${lib.concatStringsSep "," host.settings.services.tailscale.tags}"
          ];
        };

        # The install test VM has no network, so joining would only fail and retry.
        installTest.extraConfig.systemd.services.tailscaled-autoconnect.enable = lib.mkForce false;

        # Upstream tries the join once per boot, so a host whose network comes
        # up later would stay off the tailnet. It exits 0 once joined, so this
        # only retries failures.
        systemd.services.tailscaled-autoconnect = {
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "30s";
          };
          startLimitIntervalSec = 0;
        };
      };
  };

  evalTests.install-disables-autoconnect =
    perTestedHost den.aspects.services.tailscale
      (name: host: {
        installed = autoconnect (config.installTests.installedSystem host);
        real = autoconnect config.flake.nixosConfigurations.${name};
      })
      {
        installed = false;
        real = true;
      };
}
