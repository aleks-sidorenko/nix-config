{ lib, ... }:
{
  options.factory = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Functions that build per-class modules for a feature, such as `user`.";
  };
}
