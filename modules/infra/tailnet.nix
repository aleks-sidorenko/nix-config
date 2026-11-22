{
  config,
  den,
  lib,
  ...
}:
let
  acl = builtins.fromJSON config.infraStacks.tailnet.config.resource.tailscale_acl.this.acl;

  # The OAuth client hosts join with carries this tag and no other. A client
  # mints keys only for tags its own tags own, so every host tag lists it as
  # an owner. No device advertises it, so no ACL names it.
  registrarTag = "tag:registrar";
  serverTag = "tag:server";

  # A server is reached on the ports it serves and nothing else. This is the
  # layer that actually constrains tailnet peers: the daemon accepts its
  # interface's traffic in INPUT ahead of the host firewall's own chain, so a
  # service bound to all interfaces is reachable from any node whatever the
  # firewall says.
  serverPorts = [
    "22" # deploys and administration
    "80" # the reverse proxy, the only web ingress
    # 443 before anything terminates TLS, deliberately: a denied port is
    # dropped here, so a browser that upgraded the scheme waits out its
    # timeout, where reaching an unserved port gets an immediate reset.
    # Measured on this tailnet at 20s against 9ms.
    "443"
    "25565" # the game server, which is not HTTP and has its own accounts
  ];
in
{
  den = {
    quirks.tailnet-tags.description = "ACL tags a host advertises on the tailnet; the `tailnet` stack owns each one in its ACL.";

    # On the stack, not its aspect: a policy the stack aspect includes is not
    # dispatched at the stack's own scope.
    stacks.tailnet.includes = [ den.policies.tailnet-tags ];

    # Every host's tags, darwin hosts included: deriving them instead of keeping
    # a list means tagOwners can never drift from what hosts advertise, at the
    # cost of one host failing to evaluate breaking the stack for all of them.
    policies.tailnet-tags = _: [
      (den.lib.policy.pipe.from "tailnet-tags" [
        # den selects the scopes to collect from by the predicate's argument
        # names, so `host` must be named though it is not read.
        # deadnix: skip
        (den.lib.policy.pipe.collectAll ({ host, ... }: true))
      ])
    ];

    aspects.infra.tailnet = {
      includes = [ den.aspects.infra.tailscale ];

      terranix =
        { tailnet-tags, ... }:
        let
          tags = lib.unique tailnet-tags;

          tagOwners = {
            ${registrarTag} = [ "autogroup:admin" ];
          }
          // lib.genAttrs tags (_: [
            "autogroup:admin"
            registrarTag
          ]);

          # Everything that is not a server is a personal workstation, reachable
          # as before: the tightening is aimed at the homelab, not at the
          # owner's own machines.
          deviceTags = lib.filter (tag: tag != serverTag) tags;

          # Every host here advertises a tag, and a tagged device is not a
          # member of any autogroup: it has no user to belong to one. So sources
          # have to name the tags; `autogroup:member` alone matches nothing and
          # denies the tailnet to itself. It stays in the list only for a future
          # untagged device, which is also why the destinations name tags rather
          # than `autogroup:self`: that one is rejected outright once a tag
          # appears in `src`.
          workstations = deviceTags ++ [ "autogroup:member" ];
        in
        {
          # Tags let ACLs name roles instead of machines, and tag-authenticated
          # devices do not expire: infrastructure stops dropping off the tailnet
          # on the node-key schedule.
          #
          # ssh is extended beyond the default: tagged devices belong to neither
          # autogroup, so a rule targeting the tag is needed to keep --ssh
          # working once a host advertises tags.
          resource.tailscale_acl.this.acl = builtins.toJSON {
            inherit tagOwners;
            acls = [
              {
                action = "accept";
                src = workstations;
                dst = map (port: "${serverTag}:${port}") serverPorts;
              }
              {
                action = "accept";
                src = workstations;
                dst = map (tag: "${tag}:*") deviceTags;
              }
            ];
            # Same reason the acls above name tags: every host here is tagged,
            # so `autogroup:member` matches no device and `autogroup:self`
            # matches no destination. One rule over all tags rather than two,
            # since the set is derived and a new tag would otherwise need
            # remembering here.
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
        };
    };
  };

  evalTests = {
    infra-tailnet-parity = {
      expr = config.infraStacks.tailnet.config;
      expected = builtins.fromJSON (builtins.readFile ./_parity-tailnet.json);
    };
    infra-tailnet-tags = {
      expr = lib.attrNames acl.tagOwners;
      expected = [
        "tag:registrar"
        "tag:server"
        "tag:workstation"
      ];
    };
    infra-tailnet-secrets = {
      expr = lib.attrNames config.infraStacks.tailnet.meta.secrets;
      expected = [
        "TF_VAR_state_passphrase"
        "TF_VAR_tailscale_oauth_client_id"
        "TF_VAR_tailscale_oauth_client_secret"
      ];
    };
  };
}
