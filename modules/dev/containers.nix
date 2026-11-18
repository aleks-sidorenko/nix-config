{ den, ... }:
{
  den.aspects.dev.containers = {
    includes = [ den.aspects.system.homebrew ];

    darwin =
      { host, ... }:
      {
        homebrew = {
          casks = [
            {
              name = "rancher";
              greedy = false;
            }
          ];
          brews = [
            "lima"
            "docker"
            "docker-compose"
            "docker-credential-helper"
          ];
        };

        # Rancher Desktop installs its CLIs here.
        environment.variables.PATH = "$HOME/.rd/bin:$PATH";

        users.groups.podman.members = [ host.primaryUser ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = builtins.attrValues {
          inherit (pkgs)
            arion
            podman
            podman-compose
            podman-tui
            amazon-ecr-credential-helper
            ;
        };
      };
  };
}
