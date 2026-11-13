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

        # Upstream tries the join once per boot, so a host whose network comes
        # up later would stay off the tailnet. It exits 0 once joined, so this
        # only retries failures.
        # The install test VM has no network, so joining would only fail and retry.
        disko.tests.extraConfig.systemd.services.tailscaled-autoconnect.enable = lib.mkForce false;

        systemd.services.tailscaled-autoconnect = {
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "30s";
          };
          startLimitIntervalSec = 0;
        };
      };
  };
}
