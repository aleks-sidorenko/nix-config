{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.claude-code;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  options.${namespace}.cli.tools.claude-code = with types; {
    enable = mkBoolOpt false "Whether or not to enable claude-code CLI";
  };

  config = mkIf cfg.enable {
    # On Darwin, installation is handled by the darwin system module via Homebrew
    # On Linux, install via nixpkgs
    home.packages = mkIf (!isDarwin) (
      with pkgs;
      [
        claude-code
      ]
    );
  };
}
