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
  passwordStore = "${home}/.password-store";
in
{
  options.${namespace}.security.pass = with types; {
    enable = mkBoolOpt false "Whether to enable pass for password management";
  };

  config = mkIf cfg.enable {
    programs.password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = passwordStore;
      };
      package = pkgs.pass.withExtensions (p: [
        p.pass-otp
        p.pass-file
        p.pass-import
      ]);
    };

    services.pass-secret-service = mkIf pkgs.stdenv.isLinux {
      enable = true;
      storePath = passwordStore;
    };
  };
}
