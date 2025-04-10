{
  config,
  lib,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.desktops.addons.wlsunset;
in {
  options.${namespace}.desktops.addons.wlsunset = {
    enable = mkEnableOption "Enable wlsunset night light";
  };

  config = mkIf cfg.enable {
    services.wlsunset = {
      enable = true;
      latitude = "51.5072"; # FIXME
      longitude = "-0.1275";
    };
  };
}
