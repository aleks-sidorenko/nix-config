{ lib, ... }:
{
  den.aspects.infra.tailscale = {
    settings.tailnet = lib.mkOption {
      type = lib.types.str;
      default = "colobus-bramble.ts.net";
      description = "Tailnet the stack's resources belong to.";
    };

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
          inherit (stack.settings.infra.tailscale) tailnet;
        };

        # Shared by every stack that reads the tailnet, so stored once.
        _meta.secrets = {
          TF_VAR_tailscale_oauth_client_id = {
            file = "infra/secrets.yaml";
            key = "tailscale-oauth-client-id";
          };
          TF_VAR_tailscale_oauth_client_secret = {
            file = "infra/secrets.yaml";
            key = "tailscale-oauth-client-secret";
          };
        };
      };
  };
}
