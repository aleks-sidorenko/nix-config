{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.addons.xdg;

  browser = [ "firefox.desktop" ];
  editor = [ "${config.${namespace}.cli.editors.default.name}.desktop" ];
  media = [ "vlc.desktop" ];
  writer = [ "libreoffice-writer.desktop" ];
  spreadsheet = [ "libreoffice-calc.desktop" ];
  slidedeck = [ "libreoffice-impress.desktop" ];

  # Extensive list of associations here:
  # https://github.com/iggut/GamiNiX/blob/8070528de419703e13b4d234ef39f05966a7fafb/system/desktop/home-main.nix#L77
  associations = {
    "text/*" = editor;
    "text/plain" = editor;

    # "text/html" = browser;
    "application/x-zerosize" = editor; # empty files

    "application/x-shellscript" = editor;
    "application/x-perl" = editor;
    "application/json" = editor;
    "application/x-extension-htm" = browser;
    "application/x-extension-html" = browser;
    "application/x-extension-shtml" = browser;
    "application/xhtml+xml" = browser;
    "application/x-extension-xhtml" = browser;
    "application/x-extension-xht" = browser;
    "application/pdf" = browser;
    "application/mxf" = media;
    "application/sdp" = media;
    "application/smil" = media;
    "application/streamingmedia" = media;
    "application/vnd.apple.mpegurl" = media;
    "application/vnd.ms-asf" = media;
    "application/vnd.rn-realmedia" = media;
    "application/vnd.rn-realmedia-vbr" = media;
    "application/x-cue" = media;
    "application/x-extension-m4a" = media;
    "application/x-extension-mp4" = media;
    "application/x-matroska" = media;
    "application/x-mpegurl" = media;
    "application/x-ogm" = media;
    "application/x-ogm-video" = media;
    "application/x-shorten" = media;
    "application/x-smil" = media;
    "application/x-streamingmedia" = media;

    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;

    "audio/*" = media;
    "video/*" = media;
    "image/*" = browser;

    "x-scheme-handler/sgnl" = "signal-desktop.desktop";
    "application/x-010intel" = "010editor-import.desktop";
    "application/x-010motorola" = "010editor-import.desktop";
    "application/x-010project" = "010editor-project.desktop";
    "application/x-010script" = "010editor.desktop";
    "application/x-010template" = "010editor.desktop";
    "application/x-010workspace" = "010editor-project.desktop";
    "application/x-synology-drive-doc" = "synology-drive-open-file.desktop";
    "application/x-synology-drive-sheet" = "synology-drive-open-file.desktop";
    "application/x-synology-drive-slides" = "synology-drive-open-file.desktop";

    #
    # Drawio
    #
    "application/vnd.jgraph.mxfile" = [ "drawio.desktop" ];
    "application/vnd.jgraph.mxfile.realtime" = [ "drawio.desktop" ];

    #
    # Office Stuff
    #
    "text/csv" = spreadsheet;
    "application/vnd.ms-excel" = spreadsheet;
    "application/vnd.ms-powerpoint" = slidedeck;
    "application/vnd.ms-word" = writer;
    "application/vnd.oasis.opendocument.database" = [ "libreoffice-base.desktop" ];
    "application/vnd.oasis.opendocument.formula" = [ "libreoffice-math.desktop" ];
    "application/vnd.oasis.opendocument.graphics" = [ "libreoffice-draw.desktop" ];
    "application/vnd.oasis.opendocument.graphics-template" = [ "libreoffice-draw.desktop" ];
    "application/vnd.oasis.opendocument.presentation" = slidedeck;
    "application/vnd.oasis.opendocument.presentation-template" = slidedeck;
    "application/vnd.oasis.opendocument.spreadsheet" = spreadsheet;
    "application/vnd.oasis.opendocument.spreadsheet-template" = spreadsheet;
    "application/vnd.oasis.opendocument.text" = writer;
    "application/vnd.oasis.opendocument.text-master" = writer;
    "application/vnd.oasis.opendocument.text-template" = writer;
    "application/vnd.oasis.opendocument.text-web" = writer;
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = slidedeck;
    "application/vnd.openxmlformats-officedocument.presentationml.template" = slidedeck;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = spreadsheet;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = spreadsheet;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = writer;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = writer;
    "application/vnd.stardivision.calc" = spreadsheet;
    "application/vnd.stardivision.draw" = [ "libreoffice-draw.desktop" ];
    "application/vnd.stardivision.impress" = slidedeck;
    "application/vnd.stardivision.math" = [ "libreoffice-math.desktop" ];
    "application/vnd.stardivision.writer" = writer;
    "application/vnd.sun.xml.base" = [ "libreoffice-base.desktop" ];
    "application/vnd.sun.xml.calc" = spreadsheet;
    "application/vnd.sun.xml.calc.template" = spreadsheet;
    "application/vnd.sun.xml.draw" = [ "libreoffice-draw.desktop" ];
    "application/vnd.sun.xml.draw.template" = [ "libreoffice-draw.desktop" ];
    "application/vnd.sun.xml.impress" = slidedeck;
    "application/vnd.sun.xml.impress.template" = slidedeck;
    "application/vnd.sun.xml.math" = [ "libreoffice-math.desktop" ];
    "application/vnd.sun.xml.writer" = writer;
    "application/vnd.sun.xml.writer.global" = writer;
    "application/vnd.sun.xml.writer.template" = writer;
    "application/vnd.wordperfect" = writer;

  };
  removals = {
    # Calibre steals odt association from libreoffic so need to remove
    "application/vnd.oasis.opendocument.text" = [
      "calibre-ebook-viewer.desktop"
      "calibre-ebook-edit.desktop"
      "calibre-gui.desktop"
    ];
  };

in
{
  options.${namespace}.desktops.addons.xdg = with types; {
    enable = mkBoolOpt false "Enable XDG config. This includes user directories, session variables, and MIME type associations.";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      HISTFILE = lib.mkForce "${config.xdg.stateHome}/bash/history"; # TODO bash?
      GTK2_RC_FILES = lib.mkForce "${config.xdg.configHome}/gtk-2.0/gtkrc";
    };

    xdg = {
      enable = true;
      cacheHome = config.home.homeDirectory + "/.local/cache";

      configFile."mimeapps.list".force = true;
      mimeApps = {
        enable = true;
        # TODO - refactor assiciations, remove hardcoded ones, maybe move to where the app is defined
        associations.added = {
          "video/mp4" = [ "org.gnome.Totem.desktop" ];
          "video/quicktime" = [ "org.gnome.Totem.desktop" ];
          "video/webm" = [ "org.gnome.Totem.desktop" ];
          "video/x-matroska" = [ "org.gnome.Totem.desktop" ];
          "image/gif" = [ "org.gnome.Loupe.desktop" ];
          "image/png" = [ "org.gnome.Loupe.desktop" ];
          "image/jpg" = [ "org.gnome.Loupe.desktop" ];
          "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
        };

        # TODO - refactor, use browsers.default  or maybe move to where the app is defined
        # Example EmergentMind/home/ta/common/optional/xdg.nix

        defaultApplications = {
          "application/x-extension-htm" = "firefox";
          "application/x-extension-html" = "firefox";
          "application/x-extension-shtml" = "firefox";
          "application/x-extension-xht" = "firefox";
          "application/x-extension-xhtml" = "firefox";
          "application/xhtml+xml" = "firefox";
          "text/html" = "firefox";
          "x-scheme-handler/about" = "firefox";
          "x-scheme-handler/chrome" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/ftp" = "firefox";
          "x-scheme-handler/http" = "firefox";
          "x-scheme-handler/https" = "firefox";
          "x-scheme-handler/unknown" = "firefox";

          "audio/*" = [ "mpv.desktop" ];
          "video/*" = [ "org.gnome.Totem.desktop" ];
          "video/mp4" = [ "org.gnome.Totem.desktop" ];
          "video/x-matroska" = [ "org.gnome.Totem.desktop" ];
          "image/*" = [ "org.gnome.loupe.desktop" ];
          "image/png" = [ "org.gnome.loupe.desktop" ];
          "image/jpg" = [ "org.gnome.loupe.desktop" ];
          "application/json" = [ "gnome-text-editor.desktop" ];
          "application/pdf" = "firefox";
          "application/x-gnome-saved-search" = [ "org.gnome.Nautilus.desktop" ];
          "x-scheme-handler/discord" = [ "discord.desktop" ];
          "x-scheme-handler/spotify" = [ "spotify.desktop" ];
          "x-scheme-handler/tg" = [ "telegramdesktop.desktop" ];
          "application/toml" = "org.gnome.TextEditor.desktop";
          "text/plain" = "org.gnome.TextEditor.desktop";
        };
      };

      userDirs = {
        enable = true;
        createDirectories = true;
        extraConfig = {
          XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
        };
      };

      autostart.enable = true;
      portal = {
        enable = true;
      };
    };
  };
}
