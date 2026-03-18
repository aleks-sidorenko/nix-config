{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.productivity.offices.default;

  # TODO - fix this once office is configured properly # TODO - cfg.writer # TODO - cfg.calc # TODO - cfg.impress

  # Extensive list of associations here:
  # https://github.com/iggut/GamiNiX/blob/8070528de419703e13b4d234ef39f05966a7fafb/system/desktop/home-main.nix#L77

in
{
  options.${namespace}.productivity.offices.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default office";
    name = mkStringOpt' "The name of the default office to use";
    writer = mkStringOpt' "The name of the default office writer app to use";
    spreadsheet = mkStringOpt' "The name of the default office spreadsheet app to use";
    draw = mkStringOpt' "The name of the default office draw app to use";
    math = mkStringOpt' "The name of the default office math app to use";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null;
        message = "Please specify a office name in ${namespace}.productivity.offices.default";
      }
    ];

    ${namespace}.desktops.addons.xdg.associations = mkMimeAssociations cfg.name { }; # TODO
  };

}
