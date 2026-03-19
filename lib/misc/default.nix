{ lib, ... }:
with lib;
{
  mkMimeAssociations = app: types: genAttrs types (_key: [ app ]);

  mkId = parts: lib.strings.concatStringsSep "_" parts;

  mkFriendlyName = parts: lib.strings.concatStringsSep "/" parts;
}
