{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome;
in
{
  config = mkIf cfg.enable {
    # Monitor configuration for GNOME
    dconf.settings."org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };

    # Create GNOME monitors.xml configuration file from monitors module
    home.file = mkIf config.${namespace}.desktops.monitors.enable {
      ".config/monitors.xml" = {
        text =
          let
            monitorsCfg = config.${namespace}.desktops.monitors;
            allMonitors = monitorsCfg.devices;

            generateMonitorXML = monitor: ''
              <output name="${monitor.name}">
                ${if monitor.vendor != "" then ''<vendor>${monitor.vendor}</vendor>'' else ""}
                ${if monitor.model != "" then ''<product>${monitor.model}</product>'' else ""}
                <width>${toString monitor.width}</width>
                <height>${toString monitor.height}</height>
                <rate>${toString monitor.refreshRate}</rate>
                <x>${if monitor.position == "auto" then "0" else monitor.position}</x>
                <y>0</y>
                <scale>${monitor.scale}</scale>
                <primary>${if monitor.primary then "yes" else "no"}</primary>
                <enabled>${if monitor.enabled then "yes" else "no"}</enabled>
              </output>
            '';

            layoutXML = ''
              <monitors version="2">
                <configuration>
                  ${lib.concatMapStrings generateMonitorXML allMonitors}
                  <clone>no</clone>
                </configuration>
              </monitors>
            '';
          in
          layoutXML;
      };
    };
  };
}
