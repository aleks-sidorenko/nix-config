{ lib, namespace, ... }:
with lib;
let
  mkMimeAssociations = app: types: genAttrs types (key: app);
in
{
  inherit mkMimeAssociations;

  withMimeAssociations =
    {
      app,
      types,
      config,
    }:
    {
      config.${namespace}.desktops.addons.xdg.associations = (mkMimeAssociations app types);
    };
}
