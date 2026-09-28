{
  lib,
  pkgs,
  inputs,
  system,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  # Tags come from the roles a host enables (see the tailscale modules and
  # their role wiring), not a hand-maintained list, so tagOwners can never
  # drift from what hosts actually advertise.
  hostTags = host: host.config.${namespace}.services.networking.tailscale.tags or [ ];

  # Forces every host's config to evaluate on every `tailnet` run: deriving
  # tags instead of hand-maintaining them means one host failing to evaluate
  # now breaks planning for all of them. Accepted trade for a single source
  # of truth.
  allHosts =
    (attrValues (inputs.self.nixosConfigurations or { }))
    ++ (attrValues (inputs.self.darwinConfigurations or { }));

  tags = unique (concatMap hostTags allHosts);

  tagOwners = listToAttrs (map (tag: nameValuePair tag [ "autogroup:admin" ]) tags);
in
mkTerraformDerivation {
  inherit pkgs system;
  name = "tailnet";
  stateDir = "infra/tailnet";
  secretsFile = "infra/tailnet/secrets.yaml";
  secrets = {
    TF_VAR_oauth_client_id = "tailscale-oauth-client-id";
    TF_VAR_oauth_client_secret = "tailscale-oauth-client-secret";
    TF_VAR_state_passphrase = "state-passphrase";
  };
  modules = [
    {
      terraform.required_providers.tailscale = {
        source = "tailscale/tailscale";
        version = "~> 0.17";
      };

      variable = {
        oauth_client_id.type = "string";
        oauth_client_secret = {
          type = "string";
          sensitive = true;
        };
        state_passphrase = {
          type = "string";
          sensitive = true;
        };
      };

      provider.tailscale = {
        oauth_client_id = "\${var.oauth_client_id}";
        oauth_client_secret = "\${var.oauth_client_secret}";
        tailnet = defaults.network.domains.tailnet;
      };

      # Tags let ACLs name roles instead of machines, and tag-authenticated
      # devices do not expire — infrastructure stops dropping off the tailnet
      # on the node-key schedule.
      #
      # The policy is deliberately permissive: it reproduces the default
      # allow-all so adopting terraform does not change who can reach what.
      # Tightening it is separate work.
      resource.tailscale_acl.this.acl = builtins.toJSON {
        inherit tagOwners;
        acls = [
          {
            action = "accept";
            src = [ "*" ];
            dst = [ "*:*" ];
          }
        ];
        ssh = [
          {
            action = "accept";
            src = [ "autogroup:member" ];
            dst = [ "autogroup:self" ];
            users = [
              "autogroup:nonroot"
              "root"
            ];
          }
        ];
      };
    }
  ];
}
