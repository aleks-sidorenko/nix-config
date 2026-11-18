{

  den.aspects.cli.utils = {
    homeManager =
      { pkgs, ... }:
      {
        programs = {
          bottom.enable = true;
          eza.enable = true;
          zoxide = {
            enable = true;
            enableFishIntegration = true;
          };
        };

        home = {
          packages = [
            (import ./_disk-report.nix { inherit pkgs; })
          ]
          ++ builtins.attrValues {
            inherit (pkgs)
              # archivers
              zip
              unzip
              xz
              # pdf; pdfcpu cannot downsample images, so shrinking needs gs
              pdfcpu
              ghostscript
              # network
              tshark
              termshark
              kubeshark
              # basics
              coreutils
              moreutils
              # nix
              nix-output-monitor
              nvd
              nix-tree
              # modern unix
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
              jq
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
              gnused
              sd
              xcp
              yq-go
              viddy
              kaf
              ;
          };
        };
      };
  };
}
