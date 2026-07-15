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
        gaming = enabled;
        backup = enabled;
      };

      cli = {

        tools = {
          nh.enable = true;
          nix-ld.enable = true;
        };
      };

      styles.stylix.enable = true;

      desktops = {
        gnome.enable = true;
      };

      system.hibernation.enable = true;

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
