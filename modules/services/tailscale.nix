{
  config,
  den,
  lib,
  ...
}:
let
  inherit (config.installTests) perTestedHost;

  autoconnect = system: system.config.systemd.services.tailscaled-autoconnect.enable;

  secret = "system-tailscale-auth-key";

  # Required for OAuth client secrets used as auth keys; a plain,
  # already-approved key ignores it.
  authKeyParameters.preauthorized = true;

  tagFlags = host: [
    "--advertise-tags=${lib.concatStringsSep "," host.settings.services.tailscale.tags}"
  ];
in
{
  den.aspects.services.tailscale = {
    includes = [ den.aspects.security.sops ];

    # No default: the join key is an OAuth client secret, which registers only
    # a tagged node.
    settings.tags = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      description = "ACL tags the host advertises when it joins the tailnet.";
    };

    persist.directories = [ "/var/lib/tailscale" ];
    installChecks = [ ''machine.succeed("systemctl is-active tailscaled.service")'' ];

    # Joining is unattended: a host that can't decrypt the key fails
    # activation, so every host importing this must be a recipient of its
    # secrets file.
    os.sops.secrets.${secret} = { };

    nixos =
      {
        config,
        host,
        lib,
        ...
      }:
      {
        services.tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.sops.secrets.${secret}.path;
          inherit authKeyParameters;
          extraUpFlags = tagFlags host;
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

    darwin =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        params = lib.concatStringsSep "&" (
          lib.mapAttrsToList (k: v: "${k}=${lib.boolToString v}") authKeyParameters
        );
      in
      {
        services.tailscale.enable = true;

        # Mirrors the NixOS autoconnect unit, which nix-darwin lacks. It fails
        # until the secret and tailscaled are up, and launchd retries a failed run.
        launchd.daemons.tailscale-autoconnect = {
          path = [
            config.services.tailscale.package
            pkgs.jq
            pkgs.coreutils
          ];
          script = ''
            set -euo pipefail
            state() { tailscale status --json --peers=false | jq -r .BackendState; }

            # An unreachable tailscaled fails the run, so launchd retries it.
            s=$(state)
            while [ "$s" = NoState ]; do
              sleep 1
              s=$(state)
            done
            case "$s" in
              NeedsLogin | NeedsMachineAuth) ;;
              *) exit 0 ;;
            esac

            # A file keeps the key out of the process list.
            umask 077
            key=$(mktemp)
            trap 'rm -f "$key"' EXIT
            printf '%s?%s' "$(cat ${config.sops.secrets.${secret}.path})" ${lib.escapeShellArg params} > "$key"
            tailscale up --auth-key="file:$key" ${lib.escapeShellArgs (tagFlags host)}
          '';
          serviceConfig = {
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 30;
          };
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
