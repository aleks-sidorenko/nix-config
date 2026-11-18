{ den, ... }:
{
  den.aspects.cli.utils = {
    includes = [ den.aspects.system.stylix ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        programs = {
          # Manages the home on its own; harmless beside the system integration.
          home-manager.enable = true;

          bat = {
            enable = true;
            extraPackages = builtins.attrValues {
              inherit (pkgs.bat-extras)
                batgrep
                batdiff
                batman
                ;
            };
          };
          bottom.enable = true;
          eza.enable = true;
          fzf = {
            enable = true;
            # fzf-fish binds the keys itself.
            enableFishIntegration = false;
            colors = lib.mkForce (
              let
                inherit (config.lib.stylix.colors.withHashtag)
                  base00
                  base02
                  base05
                  base06
                  base08
                  base0A
                  base0E
                  ;
              in
              {
                bg = base00;
                "bg+" = base02;
                fg = base05;
                "fg+" = base05;
                header = base0E;
                hl = base08;
                "hl+" = base08;
                info = base0A;
                marker = base06;
                pointer = base06;
                prompt = base0E;
                spinner = base06;
              }
            );
          };
          htop = {
            enable = true;
            settings = {
              hide_userland_threads = 1;
              highlight_base_name = 1;
              show_cpu_temperature = 1;
              show_program_path = 0;
            };
          };
          zoxide = {
            enable = true;
            enableFishIntegration = true;
          };
        };

        home = {
          sessionVariables.MANPAGER = "batman";

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
