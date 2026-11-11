{
  config,
  inputs,
  lib,
  ...
}:
let
  # A raw `flake.deploy` set in two host files would conflict; nodes merge here.
  nodesType = lib.types.lazyAttrsOf lib.types.raw;

  merged = lib.evalModules {
    modules = [
      { options.deploy.nodes = lib.mkOption { type = nodesType; }; }
      { deploy.nodes.a = { }; }
      { deploy.nodes.b = { }; }
    ];
  };
in
{
  options.flake.deploy.nodes = lib.mkOption {
    type = nodesType;
    default = { };
    description = "deploy-rs nodes, one per deployable host, added by the host's own file.";
  };

  # Only on x86_64-linux: the activation check builds every node's profile,
  # and today every node is x86_64-linux.
  config.perSystem =
    { system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks = inputs.deploy-rs.lib.${system}.deployChecks config.flake.deploy;
    };

  config.evalTests.deploy-nodes-mergeable = {
    expr = lib.attrNames merged.config.deploy.nodes;
    expected = [
      "a"
      "b"
    ];
  };
}
