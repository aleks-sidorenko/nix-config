{
  config,
  den,
  lib,
  ...
}:
let
  names = import ./_dns-names.nix { inherit lib; };

  # The provider's API reports ttl=1 as "automatic", not a literal one-second TTL.
  automatic = 1;

  # These records were adopted from a live zone (see the `import` blocks
  # below): a Nix-side rename or a merge slip destroying them has no undo,
  # unlike a plan that merely fails. Removing one of these for real means
  # deleting this wrapper first; that friction is the point.
  protected = r: r // { lifecycle.prevent_destroy = true; };

  guarded =
    zone: records: result:
    let
      duplicateClaims = names.duplicateClaims records;
      outsideZone = names.outsideZone zone (map (r: r.name) records);
      intraHostDuplicates = names.intraHostDuplicates (
        lib.mapAttrsToList (hostname: rs: {
          inherit hostname;
          names = map (r: r.name) rs;
        }) (lib.groupBy (r: r.hostname) records)
      );
    in
    if duplicateClaims != { } then
      throw "infra/dns: service name(s) claimed by more than one host: ${
        lib.concatStringsSep ", " (
          lib.mapAttrsToList (
            name: hosts: "${name} (${lib.concatStringsSep ", " (lib.unique hosts)})"
          ) duplicateClaims
        )
      }"
    else if intraHostDuplicates != [ ] then
      throw "infra/dns: host declares the same service name twice: ${
        lib.concatStringsSep ", " (
          map (h: "${h.hostname} (${lib.concatStringsSep ", " h.duplicates})") intraHostDuplicates
        )
      }"
    else if outsideZone != [ ] then
      throw "infra/dns: published name(s) outside zone ${zone}: ${lib.concatStringsSep ", " outsideZone}"
    else
      result;
in
{
  den = {
    quirks.published-names.description = "FQDNs a host serves; the `dns` stack points each at the host's tailnet address when the host is deployed.";

    stacks.dns.includes = [ den.policies.published-names ];

    # Only deployed hosts: a stand-in host mirrors the one it replaces and
    # would claim every one of its names. Every such host must evaluate to
    # plan the zone, the accepted trade for names that come from what a host
    # serves, not a maintained list.
    policies.published-names = _: [
      (den.lib.policy.pipe.from "published-names" [
        (den.lib.policy.pipe.collectAll ({ host, ... }: host.deploy != null))
        den.lib.policy.pipe.withProvenance
      ])
    ];

    aspects.infra.dns = {
      includes = [
        den.aspects.infra.cloudflare
        den.aspects.infra.tailscale
      ];

      settings = {
        zone = lib.mkOption {
          type = lib.types.str;
          default = "sidorenko.me";
          description = "DNS zone the stack's records live in.";
        };
        # Public and stable; hardcoding it skips a `data` lookup (and its API
        # call) on every plan for information already in hand.
        zoneId = lib.mkOption {
          type = lib.types.str;
          default = "27e396c48515c243d8545764038b72e2";
          description = "Provider id of `zone`.";
        };
      };

      terranix =
        { stack, published-names, ... }:
        let
          inherit (stack.settings.infra.dns) zone zoneId;

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
            // lib.optionalAttrs (priority != null) { inherit priority; };

          # One record per (host, name) pair. Config declares more hosts than
          # are on the tailnet at any moment: pairing host with name, rather
          # than name alone, is what keeps two such hosts from colliding if
          # they ever publish the same name.
          serviceRecords = map (e: {
            hostname = e.source.host.name;
            name = e.value;
          }) published-names;
        in
        # Checked against every declared (host, name) pair, before the plan's
        # tailnet filter drops hosts that haven't joined yet.
        guarded zone serviceRecords {
          # One call listing every device, not one lookup per host: per-host
          # lookups would fail the plan on the provider's terms, with no say in
          # which absences are tolerable. Listing puts that decision in the
          # preconditions below.
          data.tailscale_devices.all = { };

          locals = {
            # Nix already knows every (host, name) pair the config wants; only
            # which hosts are actually reachable is unknown until plan time.
            service_records = serviceRecords;

            # Tailnet hostnames are machine-reported, not unique: a guest
            # reinstalled without deregistering the old node leaves two
            # devices sharing one hostname, which a plain `for` map would fail
            # on ("Duplicate object key"). The trailing `...` groups same-key
            # entries into a list instead of erroring, so the guard below can
            # name the offending hostname.
            #
            # d.addresses lists both an IPv4 (100.x) and IPv6 (fd7a:...)
            # address; addresses[0] happening to be IPv4 is not guaranteed, so
            # filter for it explicitly rather than relying on ordering.
            tailnet_device_addresses = "\${ { for d in data.tailscale_devices.all.devices : d.hostname => [for a in d.addresses : a if length(regexall(\"^[0-9.]+$\", a)) > 0][0]... } }";

            # Safe only because the guard below refuses to plan while any group
            # holds more than one device: picking a winner among them is
            # picking between a live node and a corpse, and the API orders
            # neither.
            tailnet_addresses = "\${ { for hostname, addrs in local.tailnet_device_addresses : hostname => addrs[0] } }";

            ambiguous_hostnames = "\${ [for hostname, addrs in local.tailnet_device_addresses : hostname if length(addrs) > 1] }";

            # A declared name whose host is absent from the tailnet yields no
            # resource instance, which reads as "destroy the record" rather
            # than "could not determine it".
            unresolved_hosts = "\${ distinct([for r in local.service_records : r.hostname if !contains(keys(local.tailnet_addresses), r.hostname)]) }";

            # Content below indexes this rather than a literal, so a rejoin
            # that changes the tailnet IP can't rot. The filter is retained
            # only so a missing host yields no instance rather than an index
            # error; the precondition is what stops the plan from getting that
            # far.
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

          # The static site's apex: only 185.199.109.153 was live when adopted;
          # the other three of the host's four are declared so the zone matches
          # its docs, not because they were already present.
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
              name = "www.${zone}";
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

            # A single for_each resource, not one per (host, name): each.key
            # already carries host and name, so instances can't collide, and a
            # host dropped by service_records_by_device just yields no instance
            # instead of failing the plan.
            svc =
              record {
                name = "\${each.value.name}";
                type = "A";
                content = "\${local.tailnet_addresses[each.value.hostname]}";
                # The proxy edge can't route to tailnet (CGNAT) space; every
                # other record in this zone is proxied, but these can't be.
                proxied = false;
              }
              // {
                for_each = "\${local.service_records_by_device}";
              };
          };

          # A DNS record's import id is "<zone_id>/<record_id>", not the bare
          # record id.
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
        };
    };
  };

  evalTests = {
    infra-dns-parity = {
      expr = config.infraStacks.dns.config;
      expected = builtins.fromJSON (builtins.readFile ./_parity-dns.json);
    };
    infra-dns-deploy-hosts-only = {
      expr = lib.unique (map (r: r.hostname) config.infraStacks.dns.config.locals.service_records);
      expected = [ "server" ];
    };
    infra-dns-duplicate-claims = {
      expr = names.duplicateClaims [
        {
          hostname = "a";
          name = "x.example";
        }
        {
          hostname = "b";
          name = "x.example";
        }
      ];
      expected = {
        "x.example" = [
          "a"
          "b"
        ];
      };
    };
    infra-dns-outside-zone = {
      expr = names.outsideZone "example.com" [
        "a.example.com"
        "b.other.org"
        "example.com.evil.net"
      ];
      expected = [
        "b.other.org"
        "example.com.evil.net"
      ];
    };
    infra-dns-intra-host-duplicates = {
      expr = names.intraHostDuplicates [
        {
          hostname = "a";
          names = [
            "x"
            "x"
            "y"
          ];
        }
      ];
      expected = [
        {
          hostname = "a";
          duplicates = [ "x" ];
        }
      ];
    };
    infra-dns-secrets = {
      expr = config.infraStacks.dns.meta.secrets;
      expected = {
        TF_VAR_cloudflare_api_token = {
          file = "infra/secrets.yaml";
          key = "cloudflare-api-token";
        };
        TF_VAR_tailscale_oauth_client_id = {
          file = "infra/secrets.yaml";
          key = "tailscale-oauth-client-id";
        };
        TF_VAR_tailscale_oauth_client_secret = {
          file = "infra/secrets.yaml";
          key = "tailscale-oauth-client-secret";
        };
        TF_VAR_state_passphrase = {
          file = "infra/dns/secrets.yaml";
          key = "state-passphrase";
        };
      };
    };
  };
}
