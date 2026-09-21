{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.graphical;
in
{
  options.${namespace}.roles.graphical = {
    enable = mkEnableOption "Enable the graphical environment suite (GNOME, gaming)";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles = {
        common = enabled;
        # A graphical host is a gaming host by default, but the suite is
        # x86-only (hardware.graphics.enable32Bit), so hosts can opt out.
        gaming.enable = mkDefault true;
        backup = enabled;
      };

      styles.stylix.enable = true;

      desktops = {
        gnome.enable = true;
      };

      # Meaningless on a guest, so let hosts opt out.
      system.hibernation.enable = mkDefault true;

      user = {
        # we need this for a graphical session
        extraGroups = [
          "audio"
          "sound"
          "video"
        ];
      };
    };
  };
}
