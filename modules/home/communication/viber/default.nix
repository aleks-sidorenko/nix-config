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
  cfg = config.${namespace}.communication.viber;
  viber = lib.getExe pkgs.viber;
in
{
  options.${namespace}.communication.viber = {
    enable = mkEnableOption "Enable the Viber desktop client";
    autostart = mkOption {
      type = types.bool;
      default = true;
      description = "Autostart Viber on login";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.viber ];

    xdg.configFile."autostart/viber.desktop" = mkIf cfg.autostart {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Viber
        Comment=Free calls, text and picture sharing with anyone, anywhere!
        TryExec=${viber}
        Exec=${viber} --StartInBackground %U
        Icon=viber
        Terminal=false
        Categories=Network;InstantMessaging;
        MimeType=x-scheme-handler/viber;
        Keywords=voip;chat;call;
        StartupWMClass=ViberPC
      '';
    };
  };
}
