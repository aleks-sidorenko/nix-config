{
  lib,
  pkgs,
  system,
  namespace,
  ...
}:
with lib.${namespace};
let
  inherit (defaults) backup;
in
mkTerraformDerivation {
  inherit pkgs system;
  name = "backup";
  stateDir = "infra/backup";
  secretsFile = "infra/backup/secrets.yaml";
  secrets = {
    TF_VAR_cloudflare_api_token = "cloudflare-api-token";
    TF_VAR_state_passphrase = "state-passphrase";
  };
  modules = [
    cloudflareProvider
    {
      # Bucket only. The S3 credential restic uses is made by hand and kept
      # in SOPS: minting it here would need a token able to create tokens,
      # and would put its secret in state.
      resource.cloudflare_r2_bucket.backups = {
        account_id = backup.accountId;
        name = backup.bucket;
        # Renaming the bucket plans a destroy-and-recreate of the backups' home;
        # removing this guard should be a deliberate edit.
        lifecycle.prevent_destroy = true;
      };
    }
  ];
}
