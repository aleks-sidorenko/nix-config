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
  # Public and stable; hardcoding it skips a `data` lookup (and its API call)
  # on every plan for information already in hand.
  zoneId = "27e396c48515c243d8545764038b72e2";

  # The zone these records live in, from the same registry the service names
  # are built from, so the two cannot drift apart.
  zone = defaults.network.domains.public;

  # Cloudflare's API reports ttl=1 as "automatic" — not a literal one-second TTL.
  automatic = 1;

  record =
    {
      name,
      type,
      content,
      proxied ? false,
      priority ? null,
    }:
    {
      zone_id = zoneId;
      ttl = automatic;
      inherit
        name
        type
        content
        proxied
        ;
    }
    // optionalAttrs (priority != null) { inherit priority; };

  # These records were adopted from a live zone (see the `import` block
  # below): a Nix-side rename or a merge slip destroying them has no undo,
  # unlike a plan that merely fails. Removing one of these for real means
  # deleting this wrapper first — that friction is the point.
  protected = r: r // { lifecycle.prevent_destroy = true; };

  # Same traversal as infra/tailnet: every host's config must evaluate to plan
  # this zone, so one host failing to evaluate breaks planning for all of it.
  # Accepted trade for names that come from what's enabled, not a maintained list.
  hostNames = host: host.config.${namespace}.system.networking.names or [ ];

  contributingHosts = filter (h: h.names != [ ]) (
    mapAttrsToList (_: host: {
      hostname = host.config.networking.hostName;
      names = hostNames host;
    }) (inputs.self.nixosConfigurations or { })
  );

  # One record per (host, name) pair. Config declares more hosts than are
  # currently on the tailnet (declared, but not yet deployed) — pairing host
  # with name, rather than name alone, is what keeps two such hosts from
  # colliding if they ever advertise the same service name.
  serviceRecords = concatMap (
    h:
    map (name: {
      inherit (h) hostname;
      inherit name;
    }) h.names
  ) contributingHosts;

  # Checked against every declared (host, name) pair, before the tailnet
  # filter below drops hosts that haven't joined yet: two hosts declaring the
  # same name doesn't error at the DNS layer, it round-robins — each request
  # lands on a different host with different state, silently. The stand-in
  # arrangement makes that one role toggle away, so it has to fail here
  # rather than wait for both hosts to be reachable at once.
  duplicateClaims = filterAttrs (_: hosts: length (unique hosts) > 1) (
    mapAttrs (_: rs: map (r: r.hostname) rs) (groupBy (r: r.name) serviceRecords)
  );

  # Same shape of bug, one host over: a name declared twice on ONE host slips
  # past duplicateClaims (only one hostname per group, so `unique` collapses
  # it) and reaches Terraform as two identical service_records entries, which
  # fails at plan time with the same "duplicate key" error but no clue which
  # host caused it. Catch it here, at the source.
  duplicateName = name: names: length (filter (n: n == name) names) > 1;
  intraHostDuplicates = filter (h: h.duplicates != [ ]) (
    map (h: {
      inherit (h) hostname;
      duplicates = unique (filter (n: duplicateName n h.names) h.names);
    }) contributingHosts
  );
in
if duplicateClaims != { } then
  throw "infra/dns: service name(s) claimed by more than one host: ${
    concatStringsSep ", " (
      mapAttrsToList (name: hosts: "${name} (${concatStringsSep ", " (unique hosts)})") duplicateClaims
    )
  }"
else if intraHostDuplicates != [ ] then
  throw "infra/dns: host declares the same service name twice: ${
    concatStringsSep ", " (
      map (h: "${h.hostname} (${concatStringsSep ", " h.duplicates})") intraHostDuplicates
    )
  }"
else
  mkTerraformDerivation {
    inherit pkgs system;
    name = "dns";
    stateDir = "infra/dns";
    secretsFile = "infra/dns/secrets.yaml";
    secrets = {
      TF_VAR_cloudflare_api_token = "cloudflare-api-token";
      TF_VAR_state_passphrase = "state-passphrase";
      TF_VAR_tailscale_oauth_client_id = "tailscale-oauth-client-id";
      TF_VAR_tailscale_oauth_client_secret = "tailscale-oauth-client-secret";
    };
    modules = [
      tailscaleProvider
      {
        terraform.required_providers.cloudflare = {
          source = "cloudflare/cloudflare";
          version = "~> 5.20";
        };

        variable.cloudflare_api_token = {
          type = "string";
          sensitive = true;
        };

        provider.cloudflare = {
          api_token = "\${var.cloudflare_api_token}";
        };

        # One call listing every device, not one lookup per host: per-host
        # lookups would fail the plan on the provider's terms, with no say in
        # which absences are tolerable. Listing puts that decision in the
        # preconditions below.
        data.tailscale_devices.all = { };

        locals = {
          # Nix already knows every (host, name) pair the config wants; only
          # which hosts are actually reachable is unknown until plan time.
          service_records = map (r: {
            inherit (r) hostname name;
          }) serviceRecords;

          # Tailscale hostnames are machine-reported, not unique: a guest
          # reinstalled without deregistering the old node (e.g. `just
          # vm-install server-vm`) leaves two devices sharing one hostname,
          # which a plain `for` map would fail on ("Duplicate object key").
          # The trailing `...` groups same-key entries into a list instead of
          # erroring, so the guard below can name the offending hostname.
          #
          # d.addresses lists both an IPv4 (100.x) and IPv6 (fd7a:...)
          # address; addresses[0] happening to be IPv4 is not guaranteed, so
          # filter for it explicitly rather than relying on ordering.
          tailnet_device_addresses = "\${ { for d in data.tailscale_devices.all.devices : d.hostname => [for a in d.addresses : a if length(regexall(\"^[0-9.]+$\", a)) > 0][0]... } }";

          # Safe only because the guard below refuses to plan while any group
          # holds more than one device: picking a winner among them is picking
          # between a live node and a corpse, and the API orders neither.
          tailnet_addresses = "\${ { for hostname, addrs in local.tailnet_device_addresses : hostname => addrs[0] } }";

          ambiguous_hostnames = "\${ [for hostname, addrs in local.tailnet_device_addresses : hostname if length(addrs) > 1] }";

          # A declared name whose host is absent from the tailnet yields no
          # resource instance, which reads as "destroy the record" rather than
          # "could not determine it".
          unresolved_hosts = "\${ distinct([for r in local.service_records : r.hostname if !contains(keys(local.tailnet_addresses), r.hostname)]) }";

          # Content below indexes this rather than a literal, so a rejoin that
          # changes the tailnet IP can't rot. The filter is retained only so a
          # missing host yields no instance rather than an index error; the
          # precondition is what stops the plan from getting that far.
          service_records_by_device = "\${ { for r in local.service_records : \"\${r.hostname}:\${r.name}\" => r if contains(keys(local.tailnet_addresses), r.hostname) } }";
        };

        # Preconditions ride a resource of their own: on `svc` they would go
        # unevaluated in exactly the case that needs catching, when for_each
        # resolves to nothing and every record is queued for destruction.
        resource.terraform_data.guard.lifecycle.precondition = [
          {
            condition = "\${length(local.ambiguous_hostnames) == 0}";
            error_message = "tailnet hostname claimed by more than one device (delete the stale node): \${join(\", \", local.ambiguous_hostnames)}";
          }
          {
            condition = "\${length(local.unresolved_hosts) == 0}";
            error_message = "host declares service names but is not on the tailnet (join it, or disable the services): \${join(\", \", local.unresolved_hosts)}";
          }
        ];

        # GitHub Pages apex: only 185.199.109.153 is live today; the other three
        # of GitHub's four are declared now so the zone matches GitHub's docs,
        # not because they were already present.
        resource.cloudflare_dns_record = {
          apex_a_108 = record {
            name = zone;
            type = "A";
            content = "185.199.108.153";
            proxied = true;
          };
          apex_a_109 = record {
            name = zone;
            type = "A";
            content = "185.199.109.153";
            proxied = true;
          };
          apex_a_110 = record {
            name = zone;
            type = "A";
            content = "185.199.110.153";
            proxied = true;
          };
          apex_a_111 = record {
            name = zone;
            type = "A";
            content = "185.199.111.153";
            proxied = true;
          };
          www = protected (record {
            name = hosts.public "www";
            type = "CNAME";
            content = "aleks-sidorenko.github.io";
            proxied = true;
          });
          # Same name and priority; only content tells the two mailservers apart.
          mx_1 = protected (record {
            name = zone;
            type = "MX";
            content = "mx1.forwardemail.net";
            priority = 10;
          });
          mx_2 = protected (record {
            name = zone;
            type = "MX";
            content = "mx2.forwardemail.net";
            priority = 10;
          });
          txt_forward_email = protected (record {
            name = zone;
            type = "TXT";
            content = ''"forward-email=aleks.sidorenko@gmail.com"'';
          });
        }
        // {
          # A single for_each resource, not one per (host, name): each.key
          # already carries host and name, so instances can't collide, and a
          # host dropped by service_records_by_device just yields no instance
          # instead of failing the plan.
          svc =
            record {
              name = "\${each.value.name}";
              type = "A";
              content = "\${local.tailnet_addresses[each.value.hostname]}";
              # Cloudflare's edge can't route to tailnet (CGNAT) space; every
              # other record in this zone is proxied, but these can't be.
              proxied = false;
            }
            // {
              for_each = "\${local.service_records_by_device}";
            };
        };

        # cloudflare_dns_record's import id is "<zone_id>/<record_id>", not the
        # bare record id.
        import = [
          {
            to = "cloudflare_dns_record.apex_a_109";
            id = "${zoneId}/78ee415e7ac67b2e6d0f65cab4b074d7";
          }
          {
            to = "cloudflare_dns_record.www";
            id = "${zoneId}/7b01a6de0ced102f13ce90fb745e5afe";
          }
          {
            to = "cloudflare_dns_record.mx_1";
            id = "${zoneId}/24a749afbbdb66f7e92d56671e8bd0ea";
          }
          {
            to = "cloudflare_dns_record.mx_2";
            id = "${zoneId}/16bb80e482202f260082854f237612f4";
          }
          {
            to = "cloudflare_dns_record.txt_forward_email";
            id = "${zoneId}/207b0a514f01808e74cb9a4109a4c7c4";
          }
        ];
      }
    ];
  }
