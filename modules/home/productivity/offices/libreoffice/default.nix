{
  inputs,
  lib,
  host,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.productivity.offices.libreoffice;

in
{
  options.${namespace}.productivity.offices.libreoffice = {
    enable = mkEnableOption "Enable or disable the LibreOffice.";
    default = mkBoolOpt false "Whether or not to use LibreOffice as the default office program.";
  };

  config = mkIf cfg.enable {

    ${namespace}.productivity.offices.default = mkIf cfg.default {
      enable = true;
      name = "libreoffice";
    };

    # TODO
  };

}
