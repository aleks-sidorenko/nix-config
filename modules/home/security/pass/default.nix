{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.pass;
  home = config.home.homeDirectory;
in
{
  options.${namespace}.security.pass = with types; {
    enable = mkBoolOpt false "Whether to enable pass for password management.";
  };

  config = mkIf cfg.enable {
    programs.password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = "$HOME/.password-store";
      };
      package = pkgs.pass.withExtensions (p: [
        p.pass-otp
        p.pass-file
        p.pass-import
      ]);
    };

    services.pass-secret-service = {
      enable = true;
      storePath = "${home}/.password-store";
    };
  };
}
