{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.productivity.offices.default;

  # TODO - fix this once office is configured properly

  writer = [ "libreoffice-writer.desktop" ]; # TODO - cfg.writer
  spreadsheet = [ "libreoffice-calc.desktop" ]; # TODO - cfg.calc
  slidedeck = [ "libreoffice-impress.desktop" ]; # TODO - cfg.impress

  # Extensive list of associations here:
  # https://github.com/iggut/GamiNiX/blob/8070528de419703e13b4d234ef39f05966a7fafb/system/desktop/home-main.nix#L77
  associations = {

    #
    # Drawio
    #
    # "application/vnd.jgraph.mxfile" = [ "drawio.desktop" ]; # TODO
    # "application/vnd.jgraph.mxfile.realtime" = [ "drawio.desktop" ]; # TODO

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
  options.${namespace}.productivity.offices.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default office.";
    name = mkStringOpt' "The name of the default office to use.";
    writer = mkStringOpt' "The name of the default office writer app to use.";
    spreadsheet = mkStringOpt' "The name of the default office spreadsheet app to use.";
    draw = mkStringOpt' "The name of the default office draw app to use.";
    math = mkStringOpt' "The name of the default office math app to use.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a office name in ${namespace}.productivity.offices.default.";
      }
    ];

    ${namespace}.desktops.addons.xdg.associations = mkMimeAssociations cfg.name { }; # TODO
  };

}
