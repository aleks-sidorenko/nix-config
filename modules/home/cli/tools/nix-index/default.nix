{
  lib,
  config,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.nix-index;
in
{
  options.${namespace}.cli.tools.nix-index = with types; {
    enable = mkBoolOpt false "Whether or not to nix index";
  };

  imports = with inputs; [
    nix-index-database.hmModules.nix-index
  ];

  config = mkIf cfg.enable {
    programs.nix-index = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.nix-index-database.comma.enable = true;
  };
}
