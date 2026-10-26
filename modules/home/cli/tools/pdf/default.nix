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
  cfg = config.${namespace}.cli.tools.pdf;
in
{
  options.${namespace}.cli.tools.pdf = with types; {
    enable = mkBoolOpt false "Whether or not to enable PDF tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      pdfcpu
      # pdfcpu cannot downsample images, so shrinking file size needs gs
      ghostscript
    ];
  };
}
