{ config, ... }:
let
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        sops
        tailscale
      ];
      nix-config.tailscale.tags = [ "tag:t" ];
    }).config;
in
{
  flake.modules.nixos.tailscale =
    { config, lib, ... }:
    let
      inherit (config.nix-config.tailscale) tags;
    in
    {
      options.nix-config.tailscale.tags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "ACL tags this host advertises, contributed by the features and types it imports.";
      };

      config = {
        # Joining is unattended: a host that can't decrypt the key fails
        # activation, so every host importing this must be a recipient of its
        # secrets file.
        sops.secrets."system-tailscale-auth-key" = { };

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets."system-tailscale-auth-key".path;
          # Tags are a registration-time property: `tailscale set` has no
          # `--advertise-tags`, only `tailscale up` does, and upstream applies
          # extraUpFlags only with an auth key. An already-joined host needs a
          # manual `tailscale up --advertise-tags=...` to pick up new tags.
          extraUpFlags = lib.optional (tags != [ ]) "--advertise-tags=${lib.concatStringsSep "," tags}";
          # OAuth client secrets used as auth keys require preauthorized=true
          # (https://tailscale.com/kb/1215/oauth-clients#registering-new-nodes-using-oauth-credentials);
          # a plain, already-approved auth key ignores the flag.
          authKeyParameters.preauthorized = true;
        };

        # Upstream tries the join once per boot. A host whose network comes up
        # later would stay off the tailnet until rebooted. It exits 0 once
        # joined, so this only retries failures.
        systemd.services.tailscaled-autoconnect = {
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "30s";
          };
          startLimitIntervalSec = 0;
        };
      };
    };

  evalTests = {
    tailscale-tags-flag = {
      expr = c.services.tailscale.extraUpFlags;
      expected = [ "--advertise-tags=tag:t" ];
    };
    tailscale-auth-key = {
      expr = c.services.tailscale.authKeyFile;
      expected = "/run/secrets/system-tailscale-auth-key";
    };
  };
}
