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

  # A server is reached on the ports it serves and nothing else. This is the
  # layer that actually constrains tailnet peers: `tailscaled` inserts
  # `-A ts-input -i tailscale0 -j ACCEPT` into INPUT ahead of the host
  # firewall's own chain, so a service bound to all interfaces is reachable
  # from any node whatever the firewall says.
  serverPorts = [
    "22" # deploys and administration
    "80" # nginx, the only web ingress
    # 443 before anything terminates TLS, deliberately: a denied port is
    # dropped here, so a browser that upgraded the scheme waits out its
    # timeout, where reaching an unserved port gets an immediate reset.
    # Measured on this tailnet at 20s against 9ms.
    "443"
    "25565" # minecraft, which is not HTTP and has its own accounts
  ];

  # Everything that is not a server is a personal workstation, reachable as
  # before — the tightening is aimed at the homelab, not at the owner's own
  # machines.
  deviceTags = filter (tag: tag != "tag:server") tags;

  # Every host here advertises a tag, and a tagged device is not a member of
  # any autogroup — it has no user to belong to one. So sources have to name
  # the tags; `autogroup:member` alone matches nothing and denies the tailnet
  # to itself. It stays in the list only for a future untagged device, which
  # is also why the destinations name tags rather than `autogroup:self`:
  # that one is rejected outright once a tag appears in `src`.
  workstations = deviceTags ++ [ "autogroup:member" ];
in
mkTerraformDerivation {
  inherit pkgs system;
  name = "tailnet";
  stateDir = "infra/tailnet";
  secretsFile = "infra/tailnet/secrets.yaml";
  secrets.TF_VAR_state_passphrase = "state-passphrase";
  sharedSecrets = tailscaleSecrets;
  modules = [
    tailscaleProvider
    {
      # Tags let ACLs name roles instead of machines, and tag-authenticated
      # devices do not expire — infrastructure stops dropping off the tailnet
      # on the node-key schedule.
      #
      # ssh is extended beyond the default: tagged devices belong to neither
      # autogroup, so a rule targeting the tag is needed to keep --ssh working
      # once a host advertises tags.
      resource.tailscale_acl.this.acl = builtins.toJSON {
        inherit tagOwners;
        acls = [
          {
            action = "accept";
            src = workstations;
            dst = map (port: "tag:server:${port}") serverPorts;
          }
          {
            action = "accept";
            src = workstations;
            dst = map (tag: "${tag}:*") deviceTags;
          }
        ];
        # Same reason the acls above name tags: every host here is tagged, so
        # `autogroup:member` matches no device and `autogroup:self` matches no
        # destination. One rule over all tags rather than two, since the set
        # is derived and a new tag would otherwise need remembering here.
        ssh = [
          {
            action = "accept";
            src = workstations;
            dst = tags;
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
