{ den, ... }:
let
  port = 9696;
in
{
  den.aspects.services.prowlarr = (import ./_arr.nix { inherit den; }).aspect {
    name = "prowlarr";
    title = "Prowlarr";
    inherit port;
    # Upstream runs prowlarr as a dynamic user, so its state lives under the
    # private directory, which systemd keeps at 0700.
    dataDir = "/var/lib/private/prowlarr";
    checks = [ ''machine.succeed("test \"$(stat -c %a /var/lib/private)\" = 700")'' ];
    nixos =
      _:
      { pkgs, ... }:
      {
        services.prowlarr = {
          enable = true;
          package = pkgs.unstable.prowlarr;
          settings.server.port = port;
          # nginx is the ingress; opening the port here would let clients bypass it.
          openFirewall = false;
          # Upstream's dataDir option is broken for dynamic users
          # (nixpkgs#445983), so the default location is kept.
        };

        systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];
      };
  };
}
