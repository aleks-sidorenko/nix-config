{
  globals.mapleader = " ";

  keymaps = [
    {
      mode = [
        "n"
        "x"
      ];
      key = "j";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "<Down>";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "k";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "<Up>";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        expr = true;
        silent = true;
      };
    }

    # Line navigation
    {
      mode = [
        "n"
        "v"
      ];
      key = "H";
      action = "^";
      options = {
        desc = "Go to beginning of line";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "L";
      action = "$";
      options = {
        desc = "Go to end of line";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "g[";
      action = "^";
      options = {
        desc = "Go to beginning of line";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "g]";
      action = "$";
      options = {
        desc = "Go to end of line";
      };
    }

    # Paragraph navigation
    {
      mode = [
        "n"
        "v"
      ];
      key = "J";
      action = "}";
      options = {
        desc = "Next paragraph";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "K";
      action = "{";
      options = {
        desc = "Previous paragraph";
      };
    }

    # Relocated defaults (displaced by J/K paragraph navigation)
    {
      mode = [
        "n"
        "v"
      ];
      key = "gJ";
      action = "J";
      options = {
        desc = "Join lines";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "gh";
      action = "K";
      options = {
        desc = "Keyword lookup / hover";
      };
    }

    # Buffer navigation (Shift+[/])
    {
      mode = "n";
      key = "{";
      action = "<cmd>BufferLineCyclePrev<cr>";
      options = {
        desc = "Previous buffer";
      };
    }
    {
      mode = "n";
      key = "}";
      action = "<cmd>BufferLineCycleNext<cr>";
      options = {
        desc = "Next buffer";
      };
    }
    # Buffer reorder (Ctrl+Shift+[/])
    {
      mode = "n";
      key = "<C-S-[>";
      action = "<cmd>BufferLineMovePrev<cr>";
      options = {
        desc = "Move buffer left";
      };
    }
    {
      mode = "n";
      key = "<C-S-]>";
      action = "<cmd>BufferLineMoveNext<cr>";
      options = {
        desc = "Move buffer right";
      };
    }

    # File navigation (Ctrl+Shift+J/K — same keys as paragraph, bigger scope)
    {
      mode = [
        "n"
        "v"
      ];
      key = "<C-S-j>";
      action = "G";
      options = {
        desc = "Go to end of file";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "<C-S-k>";
      action = "gg";
      options = {
        desc = "Go to beginning of file";
      };
    }

    # Window navigation (Ctrl+HJKL)
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options = {
        desc = "Go to Left Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options = {
        desc = "Go to Lower Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options = {
        desc = "Go to Upper Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options = {
        desc = "Go to Right Window";
        remap = true;
      };
    }

    # Window resize (Ctrl+Arrows)
    {
      mode = "n";
      key = "<C-Up>";
      action = "<cmd>resize -2<cr>";
      options = {
        desc = "Decrease Window Height";
      };
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = "<cmd>resize +2<cr>";
      options = {
        desc = "Increase Window Height";
      };
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = "<cmd>vertical resize +2<cr>";
      options = {
        desc = "Increase Window Width";
      };
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = "<cmd>vertical resize -2<cr>";
      options = {
        desc = "Decrease Window Width";
      };
    }

    # Move lines (Ctrl+Shift+</> — shift/move connotation, unbound in Ghostty)
    {
      mode = "n";
      key = "<C-S-,>";
      action = "<cmd>m .-2<cr>==";
      options = {
        desc = "Move Up";
      };
    }
    {
      mode = "n";
      key = "<C-S-.>";
      action = "<cmd>m .+1<cr>==";
      options = {
        desc = "Move Down";
      };
    }
    {
      mode = "i";
      key = "<C-S-,>";
      action = "<esc><cmd>m .-2<cr>==gi";
      options = {
        desc = "Move Up";
      };
    }
    {
      mode = "i";
      key = "<C-S-.>";
      action = "<esc><cmd>m .+1<cr>==gi";
      options = {
        desc = "Move Down";
      };
    }
    {
      mode = "v";
      key = "<C-S-,>";
      action = ":m '<-2<cr>gv=gv";
      options = {
        desc = "Move Up";
      };
    }
    {
      mode = "v";
      key = "<C-S-.>";
      action = ":m '>+1<cr>gv=gv";
      options = {
        desc = "Move Down";
      };
    }

    # Undo breakpoints
    {
      mode = "i";
      key = ";";
      action = ";<c-g>u";
    }
    {
      mode = "i";
      key = ".";
      action = ".<c-g>u";
    }
    {
      mode = "i";
      key = ";";
      action = ";<c-g>u";
    }

    # Save
    {
      mode = [
        "i"
        "x"
        "n"
        "s"
      ];
      key = "<C-s>";
      action = "<cmd>w<cr><esc>";
      options = {
        desc = "Save File";
      };
    }
    {
      mode = [
        "i"
        "n"
      ];
      key = "<esc>";
      action = "<cmd>noh<cr><esc>";
      options = {
        desc = "Escape and Clear hlsearch";
      };
    }
    {
      mode = "n";
      key = "<leader>ur";
      action = "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>";
      options = {
        desc = "Redraw / Clear hlsearch / Diff Update";
      };
    }

    # Search
    {
      mode = "n";
      key = "n";
      action = "'Nn'[v:searchforward].'zv'";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "x";
      key = "n";
      action = "'Nn'[v:searchforward]";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "o";
      key = "n";
      action = "'Nn'[v:searchforward]";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "n";
      key = "N";
      action = "'nN'[v:searchforward].'zv'";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }
    {
      mode = "x";
      key = "N";
      action = "'nN'[v:searchforward]";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }
    {
      mode = "o";
      key = "N";
      action = "'nN'[v:searchforward]";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }

    # Jumps
    {
      mode = "n";
      key = "<C-[>";
      action = "<C-o>";
      options = {
        desc = "Jump Back";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-]>";
      action = "<C-i>";
      options = {
        desc = "Jump Forward";
        remap = true;
      };
    }

    # Diagnostics
    {
      mode = "n";
      key = "<leader>cd";
      action = "vim.diagnostic.open_float";
      options = {
        desc = "Line Diagnostics";
      };
    }
    {
      mode = "n";
      key = "]d";
      action = "diagnostic_goto(true)";
      options = {
        desc = "Next Diagnostic";
      };
    }
    {
      mode = "n";
      key = "[d";
      action = "diagnostic_goto(false)";
      options = {
        desc = "Prev Diagnostic";
      };
    }
    {
      mode = "n";
      key = "]e";
      action = "diagnostic_goto(true 'ERROR')";
      options = {
        desc = "Next Error";
      };
    }
    {
      mode = "n";
      key = "[e";
      action = "diagnostic_goto(false 'ERROR')";
      options = {
        desc = "Prev Error";
      };
    }
    {
      mode = "n";
      key = "]w";
      action = "diagnostic_goto(true 'WARN')";
      options = {
        desc = "Next Warning";
      };
    }
    {
      mode = "n";
      key = "[w";
      action = "diagnostic_goto(false 'WARN')";
      options = {
        desc = "Prev Warning";
      };
    }

    # General
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>qa<cr>";
      options = {
        desc = "Quit All";
      };
    }
    {
      mode = "n";
      key = "<leader>ui";
      action = "vim.show_pos";
      options = {
        desc = "Inspect Pos";
      };
    }
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<c-\\><c-n>";
      options = {
        desc = "Enter Normal Mode";
      };
    }

    # Windows (terminal mode)
    {
      mode = "t";
      key = "<C-h>";
      action = "<cmd>wincmd h<cr>";
      options = {
        desc = "Go to Left Window";
      };
    }
    {
      mode = "t";
      key = "<C-j>";
      action = "<cmd>wincmd j<cr>";
      options = {
        desc = "Go to Lower Window";
      };
    }
    {
      mode = "t";
      key = "<C-k>";
      action = "<cmd>wincmd k<cr>";
      options = {
        desc = "Go to Upper Window";
      };
    }
    {
      mode = "t";
      key = "<C-l>";
      action = "<cmd>wincmd l<cr>";
      options = {
        desc = "Go to Right Window";
      };
    }

    # Window management (Leader+w)
    {
      mode = "n";
      key = "<leader>wh";
      action = "<C-w>h";
      options = {
        desc = "Go to Left Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wj";
      action = "<C-w>j";
      options = {
        desc = "Go to Lower Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wk";
      action = "<C-w>k";
      options = {
        desc = "Go to Upper Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wl";
      action = "<C-w>l";
      options = {
        desc = "Go to Right Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wp";
      action = "<C-W>p";
      options = {
        desc = "Previous Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wq";
      action = "<C-W>c";
      options = {
        desc = "Close Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>w|";
      action = "<C-W>v";
      options = {
        desc = "Split Window Right";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>w-";
      action = "<C-W>s";
      options = {
        desc = "Split Window Below";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wm";
      action = "<C-W>o";
      options = {
        desc = "Maximize Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>w=";
      action = "<C-W>=";
      options = {
        desc = "Equalize Window Sizes";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-W>s";
      options = {
        desc = "Split Window Below";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-W>v";
      options = {
        desc = "Split Window Right";
        remap = true;
      };
    }

    # Buffer navigation (Leader+N for direct access)
    {
      mode = "n";
      key = "<leader>1";
      action = "<cmd>BufferLineGoToBuffer 1<cr>";
      options = {
        desc = "Go to buffer 1";
      };
    }
    {
      mode = "n";
      key = "<leader>2";
      action = "<cmd>BufferLineGoToBuffer 2<cr>";
      options = {
        desc = "Go to buffer 2";
      };
    }
    {
      mode = "n";
      key = "<leader>3";
      action = "<cmd>BufferLineGoToBuffer 3<cr>";
      options = {
        desc = "Go to buffer 3";
      };
    }
    {
      mode = "n";
      key = "<leader>4";
      action = "<cmd>BufferLineGoToBuffer 4<cr>";
      options = {
        desc = "Go to buffer 4";
      };
    }
    {
      mode = "n";
      key = "<leader>5";
      action = "<cmd>BufferLineGoToBuffer 5<cr>";
      options = {
        desc = "Go to buffer 5";
      };
    }
    {
      mode = "n";
      key = "<leader>6";
      action = "<cmd>BufferLineGoToBuffer 6<cr>";
      options = {
        desc = "Go to buffer 6";
      };
    }
    {
      mode = "n";
      key = "<leader>7";
      action = "<cmd>BufferLineGoToBuffer 7<cr>";
      options = {
        desc = "Go to buffer 7";
      };
    }
    {
      mode = "n";
      key = "<leader>8";
      action = "<cmd>BufferLineGoToBuffer 8<cr>";
      options = {
        desc = "Go to buffer 8";
      };
    }
    {
      mode = "n";
      key = "<leader>9";
      action = "<cmd>BufferLineGoToBuffer 9<cr>";
      options = {
        desc = "Go to buffer 9";
      };
    }

    # Tabs
    {
      mode = "n";
      key = "<leader><tab>l";
      action = "<cmd>tablast<cr>";
      options = {
        desc = "Last Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>f";
      action = "<cmd>tabfirst<cr>";
      options = {
        desc = "First Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>n";
      action = "<cmd>tabnew<cr>";
      options = {
        desc = "New Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>]";
      action = "<cmd>tabnext<cr>";
      options = {
        desc = "Next Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>q";
      action = "<cmd>tabclose<cr>";
      options = {
        desc = "Close Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>[";
      action = "<cmd>tabprevious<cr>";
      options = {
        desc = "Previous Tab";
      };
    }

  ];
}
