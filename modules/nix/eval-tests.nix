{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  tests = config.evalTests;
in
{
  options.evalTests = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          expr = mkOption { type = types.raw; };
          expected = mkOption { type = types.raw; };
        };
      }
    );
    default = { };
    description = "Evaluation-time assertions, run by the `eval` flake check.";
  };

  config.perSystem =
    { pkgs, ... }:
    {
      checks.eval =
        let
          failures = lib.runTests (lib.mapAttrs' (n: t: lib.nameValuePair "test-${n}" t) tests);
        in
        if failures == [ ] then
          pkgs.runCommand "eval-tests" { } "touch $out"
        else
          throw "eval tests failed: ${builtins.toJSON failures}";
    };
}
