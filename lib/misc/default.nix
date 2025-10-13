{ lib, namespace, ... }:
with lib;
{
  mkMimeAssociations = app: types: genAttrs types (key: [ app ]);

  mkId = parts:
    lib.strings.concatStringsSep "_" parts;

  mkFriendlyName = parts:
    let
      capitalize = str:
        if str == "" then ""
        else
          (lib.strings.toUpper (builtins.substring 0 1 str)) +
          (builtins.substring 1 (builtins.stringLength str) str);
    in
    lib.strings.concatStringsSep " / " (map capitalize parts);
}
