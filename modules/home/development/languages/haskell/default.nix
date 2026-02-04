{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.development.languages.haskell;
in
{
  options.${namespace}.development.languages.haskell = {
    enable = mkEnableOption "Whether to configure Haskell development";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Haskell toolchain
      ghc
      cabal-install
      stack
      # Language server
      haskell-language-server
      # Formatters
      ormolu
      stylish-haskell
      # Additional tools
      haskellPackages.hoogle
      haskellPackages.fast-tags
      haskellPackages.hlint

    ];
  };
}
