{
  config,
  den,
  ...
}:
{
  den.stacks.storage = { };

  den.aspects.infra.storage = {
    includes = [ den.aspects.infra.cloudflare ];

    # The restic S3 credential is made by hand and kept in SOPS: minting it
    # here would need a token that creates tokens, and would put its secret
    # in state.
    terranix =
      { stack, ... }:
      {
        resource.cloudflare_r2_bucket.backups = {
          account_id = stack.settings.infra.cloudflare.accountId;
          name = "backups";
          # Renaming the bucket plans a destroy-and-recreate of the backups'
          # home; dropping this guard should be a deliberate edit.
          lifecycle.prevent_destroy = true;
        };
      };
  };

  evalTests = {
    infra-storage-parity = {
      expr = config.infraStacks.storage.config;
      expected = builtins.fromJSON (builtins.readFile ./_parity-storage.json);
    };
    infra-storage-secrets = {
      expr = config.infraStacks.storage.meta.secrets;
      expected = {
        TF_VAR_cloudflare_api_token = {
          file = "infra/secrets.yaml";
          key = "cloudflare-api-token";
        };
        TF_VAR_state_passphrase = {
          file = "infra/storage/secrets.yaml";
          key = "state-passphrase";
        };
      };
    };
  };
}
