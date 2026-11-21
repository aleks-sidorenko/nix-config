{ lib, ... }:
{
  den.aspects.infra.cloudflare = {
    settings.accountId = lib.mkOption {
      type = lib.types.str;
      default = "4e18ae7a3707f53f8d7cd82fb8e6abad";
      description = "Cloudflare account the stack's resources belong to.";
    };

    terranix = {
      terraform.required_providers.cloudflare = {
        source = "cloudflare/cloudflare";
        version = "~> 5.20";
      };

      variable.cloudflare_api_token = {
        type = "string";
        sensitive = true;
      };

      provider.cloudflare.api_token = "\${var.cloudflare_api_token}";

      # Shared by every stack that manages the account, so stored once.
      _meta.secrets.TF_VAR_cloudflare_api_token = {
        file = "infra/secrets.yaml";
        key = "cloudflare-api-token";
      };
    };
  };
}
