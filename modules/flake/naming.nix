# The aspect naming convention: den.aspects holds hosts, users and categories;
# a feature's path mirrors its file under modules/; no segment is a key den
# reads as an instruction.
{
  den,
  lib,
  options,
  ...
}:
let
  modules = ./..;
  inherit (den.lib.aspects.fx.keyClassification) isStructuralKey;
  isReserved = import ../_lib/reserved-key.nix { inherit den; };

  hosts = lib.concatMap lib.attrValues (lib.attrValues den.hosts);
  entities = lib.unique (
    map (host: host.name) hosts ++ lib.concatMap (host: lib.attrNames host.users) hosts
  );

  # Only names this flake declares; den's batteries add top-level aspects too.
  declared = lib.unique (
    lib.concatMap (
      def:
      lib.optionals (lib.hasPrefix "${toString modules}/" def.file) (
        lib.attrNames (def.value.aspects or { })
      )
    ) options.den.definitionsWithLocations
  );
  categories = lib.subtractLists entities declared;

  # A category holds nothing itself, so every key under it is a feature,
  # reserved ones included.
  features = lib.concatMap (
    category:
    map (feature: [
      category
      feature
    ]) (lib.filter (k: !isStructuralKey k) (lib.attrNames den.aspects.${category}))
  ) categories;

  # Inside a feature, reserved keys are its content and provides children are
  # cross-entity keys; what remains are variants.
  variants = lib.concatMap (
    path:
    let
      aspect = lib.getAttrFromPath path den.aspects;
      forwarded = aspect.__providesForwarded or [ ];
    in
    map (variant: path ++ [ variant ]) (
      lib.filter (k: !isReserved k && !lib.elem k forwarded) (lib.attrNames aspect)
    )
  ) features;

  # A variant with a reserved name reads as feature content, so only its file
  # gives it away. `default.nix` stands for its directory; `_` files are helpers.
  filePaths =
    category:
    let
      dir = modules + "/${category}";
      relative = file: lib.removePrefix "${toString dir}/" (toString file);
      toPath =
        file:
        [ category ]
        ++ lib.splitString "/" (lib.removeSuffix "/default" (lib.removeSuffix ".nix" (relative file)));
    in
    lib.optionals (builtins.pathExists dir) (
      lib.filter (path: !lib.any (lib.hasPrefix "_") path) (
        map toPath (
          lib.filter (lib.hasSuffix ".nix") (map toString (lib.filesystem.listFilesRecursive dir))
        )
      )
    );

  hasFile =
    path:
    let
      file = lib.concatStringsSep "/" path;
    in
    builtins.pathExists (modules + "/${file}.nix")
    || (lib.length path == 2 && builtins.pathExists (modules + "/${file}/default.nix"));

  dotted = map (lib.concatStringsSep ".");
in
{
  evalTests = {
    naming-reserved-segments = {
      expr = lib.unique (
        dotted (lib.filter (lib.any isReserved) (features ++ lib.concatMap filePaths categories))
      );
      expected = [ ];
    };
    # An entity named after a category merges into it, which den.aspects can't
    # tell apart; the category's directory can.
    naming-entity-category-clash = {
      expr = lib.filter (name: builtins.pathExists (modules + "/${name}")) entities;
      expected = [ ];
    };
    naming-feature-files = {
      expr = dotted (lib.filter (path: !hasFile path) (features ++ variants));
      expected = [ ];
    };
  };
}
