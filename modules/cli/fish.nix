{ den, ... }:
{
  den.aspects.cli.fish = {
    includes = [ den.aspects.system.stylix ];

    homeManager =
      {
        host,
        pkgs,
        ...
      }:
      {
        catppuccin.fish.enable = true;

        programs.fish = {
          enable = true;
          interactiveShellInit = ''
            ${pkgs.nix-your-shell}/bin/nix-your-shell --nom fish | source

            fish_add_path ~/.local/bin

            fish_vi_key_bindings
            set fish_cursor_default     block      blink
            set fish_cursor_insert      line       blink
            set fish_cursor_replace_one underscore blink
            set fish_cursor_visual      block

            # fifc setup
            set -g fifc_editor nvim
            set -g fifc_keybinding \cx
            bind \cx _fifc
            bind -M insert \cx _fifc

            fzf_configure_bindings

            # Restore autosuggestion bindings overridden by fzf-fish plugin
            bind -M insert \cf accept-autosuggestion
            bind -M insert \ef forward-word

            # Correct cursor for ghostty when in VI mode.
            if string match -q -- '*ghostty*' $TERM
              set -g fish_vi_force_cursor 1
            end

          '';

          shellAliases.wget = "wget --hsts-file=\"$XDG_DATA_HOME/wget-hsts\"";

          # Shortcuts for a tool live in that tool's aspect.
          shellAbbrs = {
            vim = "nvim";
            n = "nvim";
            sudo = "sudo -E";

            tsu = "tailscale up";
            tsd = "tailscale down";

            # nix
            nd = "nix develop";
            nfu = "nix flake update";
            nho = "nh darwin switch ~/.nix-config -H ${host.name}";
            nrs = "darwin-rebuild switch --flake ~/.nix-config#${host.name}";

            # new commands
            weather = "curl wttr.in/Kyiv";

            pfile = "fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'";
            tldrf = "${pkgs.tldr}/bin/tldr --list | fzf --preview \"${pkgs.tldr}/bin/tldr {1} --color\" --preview-window=right,70% | xargs tldr";
          };

          functions = {
            fish_greeting = "";

            envsource = ''
              for line in (cat $argv | grep -v '^#')
                set item (string split -m 1 '=' $line)
                set -gx $item[1] $item[2]
                echo "Exported key $item[1]"
              end
            '';

            rgvim = ''
              rg --color=always --line-number --no-heading --smart-case "$argv" |
                fzf --ansi \
                    --color "hl:-1:underline,hl+:-1:underline:reverse" \
                    --delimiter : \
                    --preview 'bat --color=always {1} --highlight-line {2}' \
                    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
                    --bind 'enter:become(nvim {1} +{2})'
            '';

            fish_command_not_found = ''
              # If you run the command with comma, running the same command
              # will not prompt for confirmation for the rest of the session
              if contains $argv[1] $__command_not_found_confirmed_commands
                or ${pkgs.gum}/bin/gum confirm --selected.background=2 "Run using comma?"

                # Not bothering with capturing the status of the command, just run it again
                if not contains $argv[1] $__command_not_found_confirmed_commands
                  set -ga __command_not_found_confirmed_commands $argv[1]
                end

                comma -- $argv
                return 0
              else
                __fish_default_command_not_found_handler $argv
              end
            '';
          };

          plugins = [
            {
              name = "bass";
              inherit (pkgs.fishPlugins.bass) src;
            }
            {
              name = "fzf-fish";
              inherit (pkgs.fishPlugins.fzf-fish) src;
            }
            {
              name = "fifc";
              inherit (pkgs.fishPlugins.fifc) src;
            }
            {
              name = "git-abbr";
              inherit (pkgs.fishPlugins.git-abbr) src;
            }
          ];
        };
      };
  };
}
