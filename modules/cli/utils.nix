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
            du = "dust";
            df = "duf";
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
              # archives
              ouch
              unzip
              xz
              zip

              # basics
              coreutils
              gnused
              moreutils

              # data: json, yaml
              jnv
              jq
              jqp
              yq-go

              # dev
              entr
              hyperfine
              kaf
              tokei

              # disk
              disk-report
              duf
              dust
              dysk
              fclones
              gdu

              # files
              broot
              erdtree
              fd
              gtrash
              trash-cli
              xcp

              # network
              curlie
              doggo
              gping
              termshark
              tshark

              # nix
              nix-output-monitor
              nix-tree
              nvd

              # pdf; pdfcpu cannot downsample images, so shrinking needs gs
              ghostscript
              pdfcpu

              # processes
              procs
              viddy

              # text search and edit
              choose
              grex
              ripgrep
              sd
              silver-searcher

              # viewers
              chafa
              delta
              hexyl
              tailspin
              ;
          };
        };
      };
  };
}
