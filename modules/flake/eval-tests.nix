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

  options.perHost = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = "An eval test that `probe name host` is `expected` on each of `hosts`; with none it fails instead of passing vacuously.";
  };

  config = {
    perHost = hosts: probe: expected: {
      expr = {
        any = hosts != { };
        hosts = lib.mapAttrs probe hosts;
      };
      expected = {
        any = true;
        hosts = lib.mapAttrs (_: _: expected) hosts;
      };
    };

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
