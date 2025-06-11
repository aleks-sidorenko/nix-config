{ lib, namespace, ... }:
with lib;
{
  mkMimeAssociations = app: types: genAttrs types (key: [ app ]);
}
