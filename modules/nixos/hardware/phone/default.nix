{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.phone;
in
{
  options.${namespace}.hardware.phone = {
    enable = mkBoolOpt false "USB phone integration (usbmuxd for iOS, MTP udev rules for Android)";
  };

  config = mkIf cfg.enable {
    services.usbmuxd.enable = true;
    # libmtp ships the MTP uaccess udev rules. (android-udev-rules was removed
    # from nixpkgs — superseded by built-in systemd uaccess rules.)
    services.udev.packages = [ pkgs.libmtp ];
  };
}
