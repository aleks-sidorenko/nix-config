{
  config,
  den,
  lib,
  ...
}:
let
  # Hosts whose install test boots this aspect.
  installTested = lib.filterAttrs (
    _: host:
    host.hasAspect den.aspects.services.tailscale && host.hasAspect den.aspects.hardware.qemu-guest
  ) den.hosts.x86_64-linux;

  autoconnect = system: system.config.systemd.services.tailscaled-autoconnect.enable;
in
{
  den.aspects.services.tailscale = {
    persist.directories = [ "/var/lib/tailscale" ];
    installChecks = [ ''machine.succeed("systemctl is-active tailscaled.service")'' ];

    nixos =
      { config, lib, ... }:
      {
        # Joining is unattended: a host that can't decrypt the key fails
        # activation, so every host importing this must be a recipient of its
        # secrets file.
        sops.secrets."system-tailscale-auth-key" = { };

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets."system-tailscale-auth-key".path;
          # Required for OAuth client secrets used as auth keys; a plain,
          # already-approved key ignores it.
          authKeyParameters.preauthorized = true;
        };

        # The install test VM has no network, so joining would only fail and retry.
        disko.tests.extraConfig.systemd.services.tailscaled-autoconnect.enable = lib.mkForce false;

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

  evalTests.install-disables-autoconnect = {
    expr = lib.mapAttrs (name: host: {
      installed = autoconnect (config.installedSystem host);
      real = autoconnect config.flake.nixosConfigurations.${name};
    }) installTested;
    expected = lib.mapAttrs (_: _: {
      installed = false;
      real = true;
    }) installTested;
  };
}
