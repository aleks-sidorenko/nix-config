{
  config,
  den,
  lib,
  ...
}:
let
  secretsFile = import ./_secrets.nix;
  secrets = {
    TF_VAR_tailscale_oauth_client_id = {
      file = secretsFile;
      key = "tailscale-oauth-client-id";
    };
    TF_VAR_tailscale_oauth_client_secret = {
      file = secretsFile;
      key = "tailscale-oauth-client-secret";
    };
  };
in
{
  den.aspects.infra.tailscale = {
    # The tailnet's name is the hosts' MagicDNS domain, owned there.
    includes = [ den.aspects.system.networking ];

    terranix =
      { stack, ... }:
      {
        terraform.required_providers.tailscale = {
          source = "tailscale/tailscale";
          version = "~> 0.17";
        };

        variable = {
          tailscale_oauth_client_id.type = "string";
          tailscale_oauth_client_secret = {
            type = "string";
            sensitive = true;
          };
        };

        provider.tailscale = {
          oauth_client_id = "\${var.tailscale_oauth_client_id}";
          oauth_client_secret = "\${var.tailscale_oauth_client_secret}";
          tailnet = stack.settings.system.networking.domains.tailnet;
        };

        # Shared by every stack that reads the tailnet, so stored once.
        _meta = { inherit secrets; };
      };
  };

  evalTests.infra-tailscale-secrets = {
    expr = lib.unique (
      lib.mapAttrsToList (_: stack: lib.intersectAttrs secrets stack.meta.secrets) (
        lib.filterAttrs (_: stack: stack.meta.secrets ? TF_VAR_tailscale_oauth_client_id) config.infraStacks
      )
    );
    expected = [
      {
        TF_VAR_tailscale_oauth_client_id = {
          file = "infra/secrets.yaml";
          key = "tailscale-oauth-client-id";
        };
        TF_VAR_tailscale_oauth_client_secret = {
          file = "infra/secrets.yaml";
          key = "tailscale-oauth-client-secret";
        };
      }
    ];
  };
}
