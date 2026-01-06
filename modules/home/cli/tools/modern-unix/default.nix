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
  cfg = config.${namespace}.cli.tools.modern-unix;
in
{
  options.${namespace}.cli.tools.modern-unix = with types; {
    enable = mkBoolOpt false "Whether or not to enable modern unix tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      broot
      choose
      curlie
      chafa
      doggo
      duf
      delta
      dust
      dysk
      entr
      erdtree
      fd
      gdu
      gping
      grex
      hyperfine
      hexyl
      jqp
      jnv
      ouch
      silver-searcher
      procs
      tokei
      trash-cli
      tailspin
      gtrash
      ripgrep
      sd
      xcp
      yq-go
      viddy
      kaf

    ];
  };
}
