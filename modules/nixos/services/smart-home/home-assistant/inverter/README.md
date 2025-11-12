# Deye Inverter Integration via Solarman

This module integrates Deye inverters with Home Assistant using the Solarman custom component.

## Prerequisites

### Automatic Installation

The Solarman custom component is **automatically installed** when you enable this module. No manual installation via HACS or manual download is required!

The module uses NixOS's declarative configuration to:
- Fetch the Solarman component from GitHub
- Install it as a Home Assistant custom component
- Configure it with your inverter settings

### Network Configuration

Make sure your Deye inverter's Solarman logger is accessible on your network. You'll need:
- IP address of the Solarman logger
- Serial number of the Solarman logger (found on the device label)

## Configuration

### Basic Setup

Enable the inverter integration in your NixOS configuration:

```nix
{
  nix-config = {
    services.smart-home.home-assistant = {
      enable = true;
      inverter = {
        enable = true;
        host = "192.168.1.100";  # Replace with your logger's IP
        serialNumber = "123456789";    # Replace with your logger's serial
      };
    };
  };
}
```

### Advanced Options

```nix
{
  nix-config = {
    services.smart-home.home-assistant = {
      enable = true;
      inverter = {
        enable = true;
        host = "192.168.1.100";
        serialNumber = "123456789";
        port = 8899;                   # Default Solarman port
        inverterModel = "deye_sg04lp3"; # Model-specific configuration file
        updateInterval = 60;            # Update every 60 seconds
      };
    };
  };
}
```

### Available Inverter Models

Common Deye inverter model identifiers:
- `deye_sg04lp3` - Deye SG04LP3 (4kW hybrid inverter)
- `deye_sg01hp3` - Deye SG01HP3 (1kW hybrid inverter)
- `deye_hybrid` - Generic Deye hybrid inverter
- `deye_string` - Deye string inverter

Check the [Solarman repository](https://github.com/StephanJoubert/home_assistant_solarman) for the full list of supported models.

## Features

Once enabled, the integration provides:

### Dashboard View
- **Solar Inverter** tab with comprehensive monitoring
- Real-time power production
- Daily/total energy production
- Grid status (voltage, frequency, power)
- Battery status (SOC, voltage, power, temperature)
- 24-hour power history graph

### Sensors

The integration creates numerous sensors including:
- `sensor.solarman_total_production` - Total energy produced
- `sensor.solarman_today_production` - Today's energy production
- `sensor.solarman_current_power` - Current power output
- `sensor.solarman_grid_voltage` - Grid voltage
- `sensor.solarman_grid_frequency` - Grid frequency
- `sensor.solarman_grid_power` - Power to/from grid
- `sensor.solarman_battery_soc` - Battery state of charge
- `sensor.solarman_battery_voltage` - Battery voltage
- `sensor.solarman_battery_power` - Battery charge/discharge power
- `sensor.solarman_battery_temperature` - Battery temperature

*Note: Actual sensor names may vary depending on your inverter model and Solarman configuration.*

## Troubleshooting

### Connection Issues

If the integration can't connect to your inverter:

1. **Check network connectivity**: Ping the logger's IP address
   ```bash
   ping 192.168.1.100
   ```

2. **Verify port**: Default is 8899, but some loggers use different ports

3. **Check serial number**: Make sure it matches exactly (found on the logger device)

4. **Firewall**: Ensure port 8899 (or your custom port) is open on your network

### Entity Not Available

If sensors show as "unavailable":

1. Check Home Assistant logs for errors
2. Verify the inverter model is correct
3. Ensure the Solarman custom component is properly installed
4. Try restarting Home Assistant

### Finding Your Configuration

Configuration files are automatically generated in:
```
/var/lib/hass/packages/inverter.yaml
```

You can check this file for the actual Solarman configuration being used.

## Example Usage in Automations

### Low Battery Notification

```yaml
automation:
  - alias: "Low Battery Alert"
    trigger:
      - platform: numeric_state
        entity_id: sensor.solarman_battery_soc
        below: 20
    action:
      - service: notify.notify
        data:
          message: "Battery is low at {{ states('sensor.solarman_battery_soc') }}%"
```

### Export Excess Solar to Grid

```yaml
automation:
  - alias: "Export Excess Solar"
    trigger:
      - platform: numeric_state
        entity_id: sensor.solarman_battery_soc
        above: 95
    condition:
      - condition: numeric_state
        entity_id: sensor.solarman_current_power
        above: 2000
    action:
      # Add your export control actions here
```

## Technical Details

### How Automated Installation Works

This NixOS module uses a declarative approach to install and configure the Solarman integration:

1. **Component Installation**: The module uses `pkgs.buildHomeAssistantComponent` to:
   - Fetch the Solarman source code from GitHub (version v5.2.2)
   - Build it as a Home Assistant custom component
   - Install it automatically when the system is rebuilt

2. **Configuration Generation**: The module generates a YAML configuration file that:
   - Contains your inverter's connection settings
   - Is placed in Home Assistant's packages directory
   - Is automatically loaded on startup

3. **Dependencies**: The module ensures all required Home Assistant components (`sensor`, `switch`) are enabled.

### Updating Solarman Version

The Solarman component version is defined in `default.nix`. To update:

1. Change the `version` field (e.g., `version = "1.5.1";`)
2. Get the new hash by running:
   ```bash
   just fetch-github-hash StephanJoubert home_assistant_solarman 1.5.1
   ```
3. Update the `hash` field in `default.nix` with the output
4. Rebuild your system

### Advantages of This Approach

- **Reproducible**: Your entire setup is defined in code
- **Version Controlled**: The Solarman version is pinned with a hash
- **No Manual Steps**: Fresh installs work without manual intervention
- **Updates**: Update the version number in `solarman/default.nix` to upgrade

## References

- [Solarman Home Assistant Integration](https://github.com/StephanJoubert/home_assistant_solarman)
- [Deye Inverter Documentation](https://www.deyeinverter.com/)
- [Home Assistant Custom Components](https://www.home-assistant.io/integrations/#custom-integrations)

