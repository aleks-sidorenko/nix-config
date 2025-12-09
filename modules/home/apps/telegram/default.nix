{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.telegram;
  telegram = getExecPath2 pkgs.telegram-desktop "Telegram";
in
{
  options.${namespace}.apps.telegram = {
    enable = mkEnableOption "Enable the Telegram desktop client.";
    autostart = mkOption {
      type = types.bool;
      default = true;
      description = "Autostart Telegram on login.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.telegram-desktop ];

    xdg.configFile."autostart/telegram-desktop.desktop" = mkIf cfg.autostart {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Telegram Desktop
        Comment=Official desktop application for the Telegram messaging service
        TryExec=${telegram}
        Exec=${telegram} -startintray
        Icon=telegram
        Terminal=false
        StartupWMClass=TelegramDesktop
        Categories=Network;InstantMessaging;Qt;
        MimeType=x-scheme-handler/tg;
        Keywords=tg;chat;im;messaging;messenger;sms;tdesktop;
        X-GNOME-UsesNotifications=true
      '';
    };
  };
}
