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
            enabledMonitors = builtins.filter (m: m.enabled) monitorsCfg.devices;

            # Calculate x positions for monitors marked as "auto"
            # This assigns cumulative horizontal positions based on monitor widths
            calculatePositions =
              monitors:
              let
                calcPos =
                  acc: monitor:
                  let
                    xPos = if monitor.position == "auto" then acc.currentX else (lib.toInt monitor.position);
                    nextX = if monitor.position == "auto" then acc.currentX + monitor.width else acc.currentX;
                  in
                  {
                    currentX = nextX;
                    monitors = acc.monitors ++ [ (monitor // { calculatedX = xPos; }) ];
                  };
              in
              (builtins.foldl' calcPos {
                currentX = 0;
                monitors = [ ];
              } monitors).monitors;

            monitorsWithPositions = calculatePositions enabledMonitors;

            generateLogicalMonitorXML =
              monitor:
              let
                vendorLine = optionalString (monitor.vendor != "") "          <vendor>${monitor.vendor}</vendor>\n";
                productLine = optionalString (monitor.model != "") "          <product>${monitor.model}</product>\n";
                serialLine = optionalString (monitor.serial != "") "          <serial>${monitor.serial}</serial>\n";
                primaryLine = optionalString monitor.primary "      <primary>yes</primary>\n";
              in
              ''
                    <logicalmonitor>
                      <x>${toString monitor.calculatedX}</x>
                      <y>0</y>
                      <scale>${monitor.scale}</scale>
                ${primaryLine}      <monitor>
                        <monitorspec>
                          <connector>${monitor.name}</connector>
                ${vendorLine}${productLine}${serialLine}        </monitorspec>
                        <mode>
                          <width>${toString monitor.width}</width>
                          <height>${toString monitor.height}</height>
                          <rate>${toString monitor.refreshRate}.000</rate>
                        </mode>
                      </monitor>
                    </logicalmonitor>
              '';

            layoutXML = ''
              <monitors version="2">
                <configuration>
                  <layoutmode>logical</layoutmode>
              ${lib.concatMapStrings generateLogicalMonitorXML monitorsWithPositions}    </configuration>
              </monitors>
            '';
          in
          layoutXML;
      };
    };
  };
}
