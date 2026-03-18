{ lib, routerConfig, ... }:
let
  inherit (routerConfig) localDomain;

  # Primary DNS records for hosts with dns=true
  primaryRecords = lib.filterAttrs (_: host: host.dns) routerConfig.hosts;

  # Alias records expanded to individual entries
  aliasEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: host:
      builtins.map (alias: {
        name = alias;
        inherit (host) ip;
      }) host.aliases
    ) routerConfig.hosts
  );
in
{
  resource.routeros_dns.settings = {
    allow_remote_requests = true;
    servers = routerConfig.dns.upstream;
  };

  resource.routeros_ip_dns_record =
    # FWD rule for *.local
    {
      local_fwd = {
        forward_to = routerConfig.gateway;
        regexp = ".*\\\\.${localDomain}$$";
        type = "FWD";
      };
    }
    # A records from hosts
    // builtins.listToAttrs (
      lib.mapAttrsToList (name: host: {
        name =
          let
            sanitized = builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
          in
          if builtins.match "[0-9].*" sanitized != null then "_${sanitized}" else sanitized;
        value = {
          address = host.ip;
          name = "${name}.${localDomain}";
          type = "A";
        };
      }) primaryRecords
    )
    # A records from aliases
    // builtins.listToAttrs (
      builtins.map (entry: {
        name = "alias_${builtins.replaceStrings [ "-" "." ] [ "_" "_" ] entry.name}";
        value = {
          address = entry.ip;
          name = "${entry.name}.${localDomain}";
          type = "A";
        };
      }) aliasEntries
    );
}
