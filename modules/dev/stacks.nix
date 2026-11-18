{ den, lib, ... }:
{
  # Per-project toolchains, never global. Not flake devShells: no eval on
  # `cd`, they work offline, and their versions follow the host lock.
  den.aspects.dev.stacks = {
    includes = [
      den.aspects.dev.direnv
      den.aspects.dev.git
    ];

    settings.npmRegistry = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "npm registry the node stack exports; null keeps the public one.";
    };

    homeManager =
      { host, pkgs, ... }:
      let
        inherit (host.settings.dev.stacks) npmRegistry;

        stacks = {
          jvm = {
            env = pkgs.buildEnv {
              name = "stack-jvm";
              paths = with pkgs; [
                jdk21
                sbt
                maven
                gradle
                metals
                coursier
                scalafmt
              ];
            };
            vars.JAVA_HOME = "${pkgs.jdk21.home}";
          };
          node = {
            env = pkgs.buildEnv {
              name = "stack-node";
              paths = [ pkgs.nodejs_22 ];
            };
            # The npm prefix stays project-local, so no NPM_CONFIG_PREFIX.
            vars = lib.optionalAttrs (npmRegistry != null) { NPM_CONFIG_REGISTRY = npmRegistry; };
          };
        };

        known = lib.concatStringsSep " " (lib.attrNames stacks);

        cases = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: stack: ''
            ${name})
              PATH_add ${stack.env}/bin
              ${lib.concatStringsSep "\n  " (
                lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") stack.vars
              )}
              ;;'') stacks
        );
      in
      {
        xdg.configFile."direnv/lib/stacks.sh".text = ''
          use_stack() {
            if [ $# -eq 0 ]; then
              echo "use_stack: unknown stack ''' (known: ${known})" >&2
              return 1
            fi
            local name
            for name in "$@"; do
              case "$name" in
                ${cases}
                *)
                  echo "use_stack: unknown stack '$name' (known: ${known})" >&2
                  return 1
                  ;;
              esac
            done
          }
        '';

        programs.git.ignores = [ ".envrc" ];
      };
  };
}
