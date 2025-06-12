let
  leader = " ";

  # ========== Modes Legend ==========
  #
  #    "n" Normal mode
  #    "i" Insert mode
  #    "v" Visual and Select mode
  #    "s" Select mode
  #    "t" Terminal mode
  #    ""  Normal, visual, select and operator-pending mode
  #    "x" Visual mode only, without select
  #    "o" Operator-pending mode
  #    "!" Insert and command-line mode
  #    "l" Insert, command-line and lang-arg mode
  #    "c" Command-line mode
  # ====================================
  modes = {
    default = "";
    normal = "n";
    insert = "i";
    visual = "v";
    terminal = "t";
    visualonly = "x";
    commandline = "c";
  };
in
{
  programs.nixvim = {
    globals = {
      mapleader = leader;
      maplocalleader = leader;
    };

    keymaps = [

      # Window
      {
        action = "<C-w>v";
        key = "<leader>|";
        options = {
          desc = "Split window right";
        };
        mode = [
          modes.normal
        ];
      }
      {
        action = "<C-w>s";
        key = "<leader>-";
        options = {
          desc = "Split window below";
        };
        mode = [
          modes.normal
        ];
      }

      # Files
      {
        action = "<cmd>w<cr><esc>";
        key = "<C-s>";
        options = {
          desc = "Save file";
        };
        mode = [
          modes.normal
          modes.visual
          modes.visualonly
        ];
      }

      # Tabs
      {
        mode = "n";
        key = "<leader>t";
        action = "+tab";
      }
      {
        mode = "n";
        key = "<leader>tn";
        action = "<CMD>tabnew<CR>";
        options.desc = "Create new tab";
      }
      {
        mode = "n";
        key = "<leader>td";
        action = "<CMD>tabclose<CR>";
        options.desc = "Close tab";
      }
      {
        mode = "n";
        key = "<leader>ts";
        action = "<CMD>tabnext<CR>";
        options.desc = "Go to the sub-sequent tab";
      }
      {
        mode = "n";
        key = "<leader>tp";
        action = "<CMD>tabprevious<CR>";
        options.desc = "Go to the previous tab";
      }
      # Terminal
      {
        # Escape terminal mode using ESC
        mode = "t";
        key = "<esc>";
        action = "<C-\\><C-n>";
        options.desc = "Escape terminal mode";
      }

    ];
  };
}
