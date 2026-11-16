let
  arr = import ./_arr.nix;
  name = "radarr";
  port = 7878;
  dataDir = "/var/lib/radarr";
in
{
  den.aspects.services.radarr = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("radarr.service")'' ];
    vhosts = [ (arr.vhost name port) ];
    nixos = arr.manager {
      inherit name port dataDir;
      title = "Radarr";
      category = "movies";
    };
  };
}
