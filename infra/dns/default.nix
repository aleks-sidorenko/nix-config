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
  # currently on the tailnet (e.g. `server` is real hardware not yet
  # deployed, standing behind its `server-vm` stand-in) — pairing host with
  # name, rather than name alone, is what keeps two such hosts from
  # colliding if they ever advertise the same service name.
  serviceRecords = concatMap (
    h:
    map (name: {
      inherit (h) hostname;
      inherit name;
    }) h.names
  ) contributingHosts;
in
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
    {
      terraform.required_providers = {
        cloudflare = {
          source = "cloudflare/cloudflare";
          version = "~> 5.20";
        };
        tailscale = {
          source = "tailscale/tailscale";
          version = "~> 0.17";
        };
      };

      variable = {
        cloudflare_api_token = {
          type = "string";
          sensitive = true;
        };
        state_passphrase = {
          type = "string";
          sensitive = true;
        };
        tailscale_oauth_client_id.type = "string";
        tailscale_oauth_client_secret = {
          type = "string";
          sensitive = true;
        };
      };

      provider.cloudflare = {
        api_token = "\${var.cloudflare_api_token}";
      };

      provider.tailscale = {
        oauth_client_id = "\${var.tailscale_oauth_client_id}";
        oauth_client_secret = "\${var.tailscale_oauth_client_secret}";
        tailnet = defaults.network.domains.tailnet;
      };

      # One call listing every device, not one lookup per host: a host that
      # contributes names but hasn't joined the tailnet yet (real hardware
      # declared in config, not yet deployed) would make a per-host lookup
      # fail the whole plan. Listing lets service_records_by_device below
      # just drop what isn't there.
      data.tailscale_devices.all = { };

      locals = {
        # Nix already knows every (host, name) pair the config wants; only
        # which hosts are actually reachable is unknown until plan time.
        service_records = map (r: {
          inherit (r) hostname name;
        }) serviceRecords;

        tailnet_addresses = "\${ { for d in data.tailscale_devices.all.devices : d.hostname => d.addresses[0] } }";

        # Content below indexes this rather than a literal, so a rejoin that
        # changes the tailnet IP can't rot; hosts absent from it are dropped.
        service_records_by_device = "\${ { for r in local.service_records : \"\${r.hostname}:\${r.name}\" => r if contains(keys(local.tailnet_addresses), r.hostname) } }";
      };

      # GitHub Pages apex: only 185.199.109.153 is live today; the other three
      # of GitHub's four are declared now so the zone matches GitHub's docs,
      # not because they were already present.
      resource.cloudflare_dns_record = {
        apex_a_108 = record {
          name = "sidorenko.me";
          type = "A";
          content = "185.199.108.153";
          proxied = true;
        };
        apex_a_109 = record {
          name = "sidorenko.me";
          type = "A";
          content = "185.199.109.153";
          proxied = true;
        };
        apex_a_110 = record {
          name = "sidorenko.me";
          type = "A";
          content = "185.199.110.153";
          proxied = true;
        };
        apex_a_111 = record {
          name = "sidorenko.me";
          type = "A";
          content = "185.199.111.153";
          proxied = true;
        };
        www = record {
          name = "www.sidorenko.me";
          type = "CNAME";
          content = "aleks-sidorenko.github.io";
          proxied = true;
        };
        # Same name and priority; only content tells the two mailservers apart.
        mx_1 = record {
          name = "sidorenko.me";
          type = "MX";
          content = "mx1.forwardemail.net";
          priority = 10;
        };
        mx_2 = record {
          name = "sidorenko.me";
          type = "MX";
          content = "mx2.forwardemail.net";
          priority = 10;
        };
        txt_forward_email = record {
          name = "sidorenko.me";
          type = "TXT";
          content = ''"forward-email=aleks.sidorenko@gmail.com"'';
        };
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
