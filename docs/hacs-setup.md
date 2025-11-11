# HACS (Home Assistant Community Store) Setup

HACS has been configured in your NixOS Home Assistant installation.

## What Was Configured

1. **HACS Module**: Created at `modules/nixos/services/smart-home/home-assistant/hacs/default.nix`
   - Fetches HACS from GitHub (version 2.0.2)
   - Adds HACS as a custom component
   - Makes configuration writable for initial setup
   - Creates necessary directories with proper permissions

2. **Smart Home Role**: Updated `modules/nixos/roles/smart-home/default.nix`
   - Enabled HACS integration

## Setup Steps After Deployment

After you deploy these changes to your system, complete the HACS setup:

1. **Clear Browser Cache**
   - Clear your browser cache to ensure the new integration appears

2. **Add HACS Integration**
   - Navigate to **Settings** → **Devices & Services** in Home Assistant
   - Click **Add Integration**
   - Search for "HACS"
   - Select HACS and follow the on-screen instructions

3. **Authenticate with GitHub**
   - During setup, you'll be prompted to authenticate with your GitHub account
   - You'll need a GitHub account if you don't already have one
   - Follow the provided link and enter the displayed code
   - Authorize HACS to access your GitHub account

4. **Complete Setup**
   - Return to Home Assistant and complete the setup process
   - HACS will appear in your Home Assistant sidebar

## Using HACS

Once configured, you can use HACS to:
- Browse and install custom integrations
- Install custom frontend components (Lovelace cards)
- Install themes
- Manage updates for custom components

## Configuration Details

- **HACS Version**: 2.0.2
- **Custom Components Directory**: `/var/lib/hass/custom_components`
- **Storage Directory**: `/var/lib/hass/.storage`

## Notes

- The configuration is set to `configWritable = true` to allow HACS to manage files
- If you want to make the configuration read-only again after setup, you can set this to `false` in the HACS module
- HACS will automatically update itself through the Home Assistant UI

## Deployment

To deploy these changes:

```bash
# Build and deploy to your server
./scripts/deploy.sh server

# Or if you're using the justfile:
just deploy server
```

After deployment, restart Home Assistant or wait for it to automatically restart.

