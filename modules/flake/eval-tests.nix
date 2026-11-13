{ config, lib, ... }:
let
  tests = config.evalTests;
in
{
  options.evalTests = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          expr = lib.mkOption { type = lib.types.raw; };
          expected = lib.mkOption { type = lib.types.raw; };
        };
      }
    );
    default = { };
    description = "Evaluation-time assertions, collected into the eval-tests check.";
  };

  config = {
    perSystem =
      { pkgs, ... }:
      let
        show = lib.generators.toPretty { };
        failures = lib.filter (m: m != null) (
          lib.mapAttrsToList (
            name: t:
            if t.expr == t.expected then null else "${name}: expected ${show t.expected}, got ${show t.expr}"
          ) tests
        );
      in
      {
        checks.eval-tests =
          if failures == [ ] then
            pkgs.runCommand "eval-tests" { } "touch $out"
          else
            throw "eval tests failed:\n${lib.concatStringsSep "\n" failures}";
      };
  };
}
