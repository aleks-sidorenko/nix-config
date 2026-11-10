{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.locale.timeZone = mkOption {
    type = types.str;
    description = "Owner's home time zone (IANA name).";
  };
}
