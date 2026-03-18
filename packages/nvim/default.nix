{
  lib,
  pkgs,
  inputs,
  system,
  ...
}:
let
  inherit (inputs) nixvim;

  nixvim' = nixvim.legacyPackages.${system};
in
nixvim'.makeNixvimWithModule {
  inherit pkgs;
  extraSpecialArgs = {
  };
  module = {
    # Define custom development options
    options = {
      development = {
        haskell.enable = lib.mkEnableOption "Haskell development support";
        rust.enable = lib.mkEnableOption "Rust development support";
        python.enable = lib.mkEnableOption "Python development support";
        go.enable = lib.mkEnableOption "Go development support";
        typescript.enable = lib.mkEnableOption "TypeScript development support";
        scala.enable = lib.mkEnableOption "Scala development support";
        java.enable = lib.mkEnableOption "Java development support";
      };
      ai = {
        copilot.enable = lib.mkEnableOption "GitHub Copilot AI assistant";
        claude-code.enable = lib.mkEnableOption "Claude Code AI assistant";
      };
    };

    # Set defaults
    config = {
      development = {
        haskell.enable = lib.mkDefault false;
        rust.enable = lib.mkDefault false;
        python.enable = lib.mkDefault false;
        go.enable = lib.mkDefault false;
        typescript.enable = lib.mkDefault false;
        scala.enable = lib.mkDefault false;
        java.enable = lib.mkDefault false;
      };
      ai = {
        copilot.enable = lib.mkDefault false;
        claude-code.enable = lib.mkDefault false;
      };
    };

    # This means I can't use `default.nix` as a filename later, because there
    # doesn't seem to be a version that is "all files recursive except THIS
    # default.nix"
    imports = lib.snowfall.fs.get-non-default-nix-files-recursive ./.;
  };
}
