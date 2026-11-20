{ lib, ... }:
let
  # Each folder under packages/ is a callPackage file usable outside this flake.
  dir = ../../packages;
  names = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
  build = callPackage: lib.genAttrs names (name: callPackage (dir + "/${name}/package.nix") { });
in
{
  flake.overlays.default = final: _prev: build final.callPackage;

  perSystem =
    { pkgs, ... }:
    let
      packages = build pkgs.callPackage;
    in
    {
      inherit packages;
      # Building a package runs its checkPhase.
      checks = lib.mapAttrs' (name: lib.nameValuePair "package-${name}") packages;
    };
}
