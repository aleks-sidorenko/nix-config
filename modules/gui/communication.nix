{ den, lib, ... }:
{
  den.aspects.gui.communication = {
    includes = [ den.aspects.system.homebrew ];

    darwin = {
      homebrew.casks = [
        "slack"
        "telegram"
        "viber"
        "zoom"
      ];
      # After the apps the role pins first, so the order is stable.
      system.defaults.dock.persistent-apps = lib.mkAfter [ "/Applications/Slack.app" ];
    };
  };
}
