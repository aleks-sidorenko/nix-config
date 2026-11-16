let
  arr = import ./_arr.nix;
  name = "sonarr";
  port = 8989;
  dataDir = "/var/lib/sonarr";
in
{
  den.aspects.services.sonarr = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("sonarr.service")'' ];
    vhosts = [ (arr.vhost name port) ];
    nixos = arr.manager {
      inherit name port dataDir;
      title = "Sonarr";
      category = "series";
    };
  };
}
