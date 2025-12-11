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
  cfg = config.${namespace}.development.haskell;
in
{
  options.${namespace}.development.haskell = {
    enable = mkOpt types.bool false "Whether to configure Haskell development.";
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
