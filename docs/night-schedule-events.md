# Night Schedule Custom Events

## Overview

This document describes the custom event system for night scheduling in Home Assistant, which allows multiple automations to react to centralized time-based events.

## Custom Events

The night schedule module fires two custom events:

### `night_on`
- **Fired at:** 23:00 (configurable)
- **Purpose:** Signals the start of night mode
- **Event Data:**
  - `time`: The configured time when the event fires
  - `source`: "night_schedule"
  - `timestamp`: ISO format timestamp of when the event was fired

### `night_off`
- **Fired at:** 07:00 (configurable)
- **Purpose:** Signals the end of night mode / start of day mode
- **Event Data:**
  - `time`: The configured time when the event fires
  - `source`: "night_schedule"
  - `timestamp`: ISO format timestamp of when the event was fired

## Configuration

The night schedule is configured in the Home Assistant module:

```nix
nix-config.services.smart-home.home-assistant.night-schedule = {
  enable = true;
  nightOnTime = "23:00";  # When to fire night_on event
  nightOffTime = "07:00"; # When to fire night_off event
};
```

## Usage in Automations

### Listening to Events in YAML

Other automations can listen to these events instead of using time triggers:

```yaml
automation:
  - id: my_night_automation
    alias: "My Night Automation"
    description: "Do something when night mode starts"
    trigger:
      - platform: event
        event_type: night_on
    action:
      - service: light.turn_off
        target:
          entity_id: light.living_room
```

### Benefits

1. **Centralized Time Management**: Change night schedule times in one place
2. **Decoupled Automations**: Automations don't need to know specific times
3. **Event Data Access**: Automations can access event metadata
4. **Easier Testing**: Fire events manually for testing
5. **Better Logging**: Central logging of schedule changes

## Current Consumers

The following modules currently use these events:

### Heatpump Module
- Listens to `night_off` → Sets minimal heating mode (15-18°C)
- Listens to `night_on` → Sets full heating mode (23-28°C)

## Adding New Event Listeners

To add a new automation that responds to night schedule events:

1. Create your automation with an event trigger:
```yaml
trigger:
  - platform: event
    event_type: night_on  # or night_off
```

2. Access event data in templates if needed:
```yaml
action:
  - service: notify.mobile_app
    data:
      message: "Night mode started at {{ trigger.event.data.time }}"
```

## Manual Event Firing (for Testing)

You can manually fire these events in Home Assistant Developer Tools:

**Event Type:** `night_on` or `night_off`

**Event Data:**
```json
{
  "time": "23:00",
  "source": "manual",
  "timestamp": "2024-01-01T23:00:00"
}
```

## Files

- **Module Definition:** `modules/nixos/services/smart-home/home-assistant/night-schedule/default.nix`
- **Consumer Example:** `modules/nixos/services/smart-home/home-assistant/heatpump/heatpump.yaml`
- **Generated Config:** `/var/lib/hass/packages/night-schedule.yaml` (runtime)

