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
      # mkAfter keeps Slack last whatever order aspects merge in.
      system.defaults.dock.persistent-apps = lib.mkAfter [ "/Applications/Slack.app" ];
    };
  };
}
