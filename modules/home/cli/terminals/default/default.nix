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
  cfg = config.${namespace}.cli.terminals.default;
in
{
  options.${namespace}.cli.terminals.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default terminal configuration";
    name = mkStringOpt' "The name of the default terminal to use";
    package = mkPackageOpt' "The package to use for the default terminal";
    sshTerm = mkStringOpt "xterm-256color" "The terminal to use for SSH";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != null && cfg.package != null;
        message = "Please specify a terminal name and package in ${namespace}.cli.terminals.default";
      }
    ];

    home.sessionVariables = {
      TERM = cfg.name;
    };

    # Add terminal to GNOME favorites
    ${namespace}.desktops.gnome.favoriteApps = [ cfg.name ];
  };

}
