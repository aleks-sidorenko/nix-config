{
  config,
  den,
  lib,
  ...
}:
let
  # Sources the library a host installs, so the check runs what direnv will.
  stacksCheck =
    pkgs: name: host:
    let
      inherit (host.settings.dev.stacks) npmRegistry;
      home =
        config.flake."${host.class}Configurations".${name}.config.home-manager.users.${host.primaryUser};
      registry =
        if npmRegistry == null then
          ''[ -z "''${NPM_CONFIG_REGISTRY:-}" ] || fail "registry set"''
        else
          ''[ "''${NPM_CONFIG_REGISTRY:-}" = ${lib.escapeShellArg npmRegistry} ] || fail "NPM_CONFIG_REGISTRY=''${NPM_CONFIG_REGISTRY:-}"'';
    in
    pkgs.runCommand "stacks-${name}"
      {
        nativeBuildInputs = [ pkgs.bash ];
        script = home.xdg.configFile."direnv/lib/stacks.sh".source;
      }
      ''
        set -eu
        PATH_add() { PATH="$1:$PATH"; }
        source "$script"

        fail() { echo "FAIL: $*" >&2; exit 1; }
        on_path() { [[ "$(command -v "$1")" == /nix/store/* ]] || fail "$1 not on PATH"; }

        (
          use_stack jvm
          for t in java sbt mvn gradle metals; do on_path "$t"; done
          [ -x "$JAVA_HOME/bin/java" ] || fail "JAVA_HOME=$JAVA_HOME"
        )
        (
          use_stack node
          for t in node npm; do on_path "$t"; done
          ${registry}
          [ -z "''${NPM_CONFIG_PREFIX:-}" ] || fail "npm prefix set"
        )
        (
          use_stack jvm node
          for t in java sbt node npm; do on_path "$t"; done
          [ -x "$JAVA_HOME/bin/java" ] || fail "JAVA_HOME=$JAVA_HOME"
          ${registry}
        )
        for args in nope ""; do
          if err=$(use_stack $args 2>&1 >/dev/null); then fail "use_stack $args succeeded"; fi
          [[ "$err" == *jvm* && "$err" == *node* ]] || fail "message: $err"
        done
        touch $out
      '';
in
{
  # One check per host of this system that includes the stacks.
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.mapAttrs' (
        name: host: lib.nameValuePair "stacks-${name}" (stacksCheck pkgs name host)
      ) (lib.filterAttrs (_: host: host.hasAspect den.aspects.dev.stacks) (den.hosts.${system} or { }));
    };

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
              paths = builtins.attrValues {
                inherit (pkgs)
                  jdk21
                  sbt
                  maven
                  gradle
                  metals
                  coursier
                  scalafmt
                  ;
              };
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
