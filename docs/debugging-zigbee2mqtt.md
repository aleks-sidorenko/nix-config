# Debugging Zigbee2MQTT and Home Assistant Integration

## Problem: Devices appear in Zigbee2MQTT but not in Home Assistant

This usually indicates an MQTT discovery issue. Follow these steps to diagnose and fix:

### 1. Check MQTT Broker (Mosquitto) Status

```bash
systemctl status mosquitto
```

Make sure it's running and active.

### 2. Check Zigbee2MQTT Logs

```bash
journalctl -u zigbee2mqtt -f
```

Look for:
- MQTT connection success messages
- Device update messages being published
- Any errors about MQTT connection

### 3. Check Home Assistant Logs

```bash
journalctl -u home-assistant -f
```

Look for:
- MQTT integration loaded
- Discovery messages received
- Any errors about MQTT

### 4. Verify MQTT Topics with mosquitto_sub

Install mosquitto clients if not already installed, then subscribe to all zigbee2mqtt topics:

```bash
mosquitto_sub -h localhost -p 1883 -u zigbee2mqtt -P <password> -t 'zigbee2mqtt/#' -v
```

You should see:
- `zigbee2mqtt/bridge/state` - Bridge status
- `zigbee2mqtt/<device_friendly_name>` - Device state updates
- `homeassistant/sensor/<device_id>/...` - Home Assistant discovery messages

### 5. Check Expected Entity IDs

Based on your device configuration:

**Garage Sensor:**
- Friendly name: `floor1/garage/temperature/sensor`
- Object ID: `floor1_garage_temperature_sensor`
- Expected entities in HA:
  - `sensor.floor1_garage_temperature_sensor_temperature`
  - `sensor.floor1_garage_temperature_sensor_humidity`
  - `sensor.floor1_garage_temperature_sensor_battery`
  - `sensor.floor1_garage_temperature_sensor_linkquality`

**Office Sensor:**
- Friendly name: `floor2/office/temperature/sensor`
- Object ID: `floor2_office_temperature_sensor`
- Expected entities in HA:
  - `sensor.floor2_office_temperature_sensor_temperature`
  - `sensor.floor2_office_temperature_sensor_humidity`
  - `sensor.floor2_office_temperature_sensor_battery`
  - `sensor.floor2_office_temperature_sensor_linkquality`

### 6. Force Discovery Re-announcement

In Home Assistant, go to:
1. **Settings** → **Devices & Services** → **MQTT**
2. Click on "Configure" 
3. Click "Re-discover"

Or restart Home Assistant:
```bash
systemctl restart home-assistant
```

### 7. Check if Devices are Publishing Data

If devices are paired but haven't sent any data yet, Home Assistant won't create entities. 

In Zigbee2MQTT dashboard:
- Click on a device
- Check "Last seen" timestamp
- Trigger a report (some sensors have a button to force update)

### 8. Verify Home Assistant MQTT Integration

In Home Assistant:
1. Go to **Settings** → **Devices & Services**
2. Check if **MQTT** integration is configured
3. If not, add it manually:
   - Broker: `localhost` or `127.0.0.1`
   - Port: `1883`
   - Discovery: enabled

### 9. Check Zigbee2MQTT Configuration

View the generated configuration:
```bash
cat /var/lib/zigbee2mqtt/configuration.yaml
```

Verify:
- `homeassistant: true` is set
- MQTT server is correct
- Devices are listed with correct `homeassistant` section

### 10. Common Fixes

**If MQTT broker password is wrong:**
Check secrets:
```bash
cat /var/lib/zigbee2mqtt/secrets.yaml
```

**If Home Assistant can't connect to MQTT:**
Ensure MQTT broker allows connections from localhost and check if authentication is required.

**If devices still don't appear:**
Try unpairing and re-pairing the device in Zigbee2MQTT.

## Verification

Once working, you should see in Home Assistant:
1. **Developer Tools** → **States** - Search for `floor1_garage` or `floor2_office`
2. All sensor entities should be listed
3. The Temperature dashboard view should display all sensors

## Entity ID Format

The entity IDs follow this pattern:
```
sensor.{zone_name}_{device_type}_{device_name}_{measurement}
```

Examples:
- `sensor.floor1_garage_temperature_sensor_temperature`
- `sensor.floor1_garage_temperature_sensor_humidity`

