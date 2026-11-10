{
  config,
  lib,
  moduleLocation,
  options,
  ...
}:
let
  inherit (lib) mapAttrs mkOption types;

  # flake-parts' own `flake.modules` sets no `key`, so an aspect reached through
  # two roles is applied twice and every list it sets is doubled. A key makes the
  # module system evaluate it once.
  keyed =
    class: name: module:
    let
      id = "${toString moduleLocation}#modules.${class}.${name}";
    in
    if class == "generic" then
      {
        key = id;
        imports = [ module ];
      }
    else
      # A function, so it's taken as a full module despite submodule shorthand.
      { ... }:
      {
        key = id;
        _class = class;
        _file = id;
        imports = [ module ];
      };

  aspects = (options.flake.type.getSubOptions [ ]).modules.apply {
    nixos.diamond-shared = {
      options.diamond = mkOption { type = types.listOf types.str; };
      config.diamond = [ "once" ];
    };
  };
  parentA = {
    imports = [ aspects.nixos.diamond-shared ];
  };
  parentB = {
    imports = [ aspects.nixos.diamond-shared ];
  };
  diamond = config.builders.nixos "x86_64-linux" {
    imports = [
      parentA
      parentB
    ];
    system.stateVersion = "26.05";
  };
in
{
  options.flake.modules = mkOption {
    type = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
    default = { };
    description = "Aspects by class (`nixos`, `darwin`, `homeManager`, `generic`), each evaluated at most once per configuration.";
    apply = mapAttrs (class: mapAttrs (keyed class));
  };

  config.evalTests.aspect-diamond-import = {
    expr = (builtins.tryEval (builtins.deepSeq diamond.config.diamond diamond.config.diamond)).value;
    expected = [ "once" ];
  };
}
