{ config, ... }:
{
  den.aspects.cli.utils = {
    os.nixpkgs.overlays = [ config.flake.overlays.default ];

    homeManager =
      { pkgs, ... }:
      {
        programs = {
          bottom.enable = true;
          eza.enable = true;
          zellij.enable = true;
          zoxide = {
            enable = true;
            enableFishIntegration = true;
          };

          fish.shellAbbrs = {
            cd = "z";
            cdi = "zi";
            cp = "xcp";
            grep = "rg";
            dig = "doggo";
            curl = "curlie";
            rm = "trash";
            ping = "gping";
            ls = "eza";
            sl = "eza";
            l = "eza --group --header --group-directories-first --long --git --all --binary --all --icons always";
            tree = "eza --tree";
          };
        };

        home = {
          packages = builtins.attrValues {
            inherit (pkgs)
              disk-report
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
