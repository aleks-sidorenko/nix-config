{ den, ... }:
{
  den.aspects.dev.containers = {
    includes = [ den.aspects.system.homebrew ];

    darwin = {
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

      # The container desktop installs its CLIs here.
      environment.variables.PATH = "$HOME/.rd/bin:$PATH";
    };

    homeManager =
      { pkgs, ... }:
      {
        programs.fish.shellAbbrs = {
          dk = "docker kill (docker ps -q)";
          ds = "docker stop (docker ps -a -q)";
          drm = "docker rm (docker ps -a -q)";
          docker-compose = "podman-compose";
        };

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
