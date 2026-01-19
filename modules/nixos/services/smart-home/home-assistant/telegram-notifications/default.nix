# Telegram Grid Notifications Module
#
# Sends notifications to a Telegram group chat when a binary sensor state changes.
# By default, monitors binary_sensor.grid_status_debounced from the inverter module.
#
# Prerequisites:
# 1. A binary sensor entity to monitor (e.g., binary_sensor.grid_status_debounced)
# 2. Create a Telegram bot via @BotFather
# 3. Add the bot to your group chat
# 4. Get the chat ID (group IDs are negative numbers)
# 5. Add secrets to SOPS:
#    - service-home-assistant-telegram-bot-token
#    - service-home-assistant-telegram-chat-id
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
with lib.${namespace};
let
  haCfg = config.${namespace}.services.smart-home.home-assistant;
  cfg = haCfg.telegram-notifications;
in
{
  options.${namespace}.services.smart-home.home-assistant.telegram-notifications = {
    enable = mkEnableOption "Enable Telegram notifications for grid status changes";

    gridStatusSensor = mkOption {
      type = types.str;
      default = "binary_sensor.grid_status_debounced";
      description = "Entity ID of the grid status sensor to monitor";
      example = "binary_sensor.grid_status_debounced";
    };

    messages = {
      gridOn = mkOption {
        type = types.str;
        default = "💡 🟰 🟢";
        description = "Message to send when grid power is restored";
      };

      gridOff = mkOption {
        type = types.str;
        default = "💡 🟰 🔴";
        description = "Message to send when grid power is lost";
      };
    };

    notifyOnStartup = mkOption {
      type = types.bool;
      default = false;
      description = "Send a notification on Home Assistant startup with current grid status";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Configure SOPS secrets for Telegram credentials
    sops.secrets."service-home-assistant-telegram-bot-token" = {
      sopsFile = ../../../../secrets.yaml;
      owner = haCfg.user;
      group = haCfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    sops.secrets."service-home-assistant-telegram-chat-id" = {
      sopsFile = ../../../../secrets.yaml;
      owner = haCfg.user;
      group = haCfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    # Register secrets with main Home Assistant module
    ${namespace} = {
      services.smart-home.home-assistant.secrets = {
        telegram_bot_token = config.sops.secrets."service-home-assistant-telegram-bot-token".path;
        telegram_chat_id = config.sops.secrets."service-home-assistant-telegram-chat-id".path;
      };
    };

    # Add Telegram components
    services.home-assistant.extraComponents = [
      "telegram"
      "telegram_bot"
    ];

    # Generate and link telegram notification configuration
    systemd.services.home-assistant.preStart = lib.mkAfter (
      let
        telegramYaml = pkgs.replaceVars ./telegram_grid_notifications.yaml {
          grid_status_sensor = cfg.gridStatusSensor;
          grid_on_message = cfg.messages.gridOn;
          grid_off_message = cfg.messages.gridOff;
          notify_on_startup = if cfg.notifyOnStartup then "true" else "false";
        };
      in
      ''
        ln -fns ${telegramYaml} ${haCfg.dataDir}/packages/telegram_grid_notifications.yaml
      ''
    );
  };
}
