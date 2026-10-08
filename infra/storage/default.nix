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
  name = "storage";
  stateDir = "infra/storage";
  secretsFile = "infra/storage/secrets.yaml";
  secrets.TF_VAR_state_passphrase = "state-passphrase";
  sharedSecrets = cloudflareSecrets;
  modules = [
    cloudflareProvider
    {
      # The R2 buckets this account uses; today `backups`. The S3 credential restic uses is made by hand and kept
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
