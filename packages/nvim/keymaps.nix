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
    {
      mode = "n";
      key = "<C-Up>";
      action = "<cmd>resize +2<cr>";
      options = {
        desc = "Increase Window Height";
      };
    }
    {
      mode = "n";
      key = "<C-Down>";
      action = "<cmd>resize -2<cr>";
      options = {
        desc = "Decrease Window Height";
      };
    }
    {
      mode = "n";
      key = "<C-Left>";
      action = "<cmd>vertical resize -2<cr>";
      options = {
        desc = "Decrease Window Width";
      };
    }
    {
      mode = "n";
      key = "<C-Right>";
      action = "<cmd>vertical resize +2<cr>";
      options = {
        desc = "Increase Window Width";
      };
    }
    {
      mode = "n";
      key = "<A-j>";
      action = "<cmd>m .+1<cr>==";
      options = {
        desc = "Move Down";
      };
    }
    {
      mode = "n";
      key = "<A-k>";
      action = "<cmd>m .-2<cr>==";
      options = {
        desc = "Move Up";
      };
    }
    {
      mode = "i";
      key = "<A-j>";
      action = "<esc><cmd>m .+1<cr>==gi";
      options = {
        desc = "Move Down";
      };
    }
    {
      mode = "i";
      key = "<A-k>";
      action = "<esc><cmd>m .-2<cr>==gi";
      options = {
        desc = "Move Up";
      };
    }
    {
      mode = "v";
      key = "<A-j>";
      action = ":m '>+1<cr>gv=gv";
      options = {
        desc = "Move Down";
      };
    }
    {
      mode = "v";
      key = "<A-k>";
      action = ":m '<-2<cr>gv=gv";
      options = {
        desc = "Move Up";
      };
    }
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
    
    # Windows
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
      key = "<leader>w-";
      action = "<C-W>s";
      options = {
        desc = "Split Window Below";
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
    
    # Terminal
    {
      mode = "n";
      key =  "<C-;>";
      action = "<cmd>terminal<cr>";
      options = {
        desc = "Toggle Terminal Window";
      };
    }
    {
      mode = "n";
      key =  "<leader>;n";
      action = "<cmd>terminal<cr>";
      options = {
        desc = "Toggle Terminal Window";
      };
    }
    {
      mode = "n";
      key = "<leader>;_";
      action = "<cmd>botright terminal<cr>";
      options = {
        desc = "Open bottom terminal";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>;|";
      action = "<cmd>vertical terminal<CR>";
      options = {
        desc = "Open a vertical terminal split";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>;-";
      action = "<cmd>horizontal terminal<CR>";
      options = {
        desc = "Open a horizontal terminal split";
        silent = true;
      };
    }
    {
      mode = "t";
      key = "<C-/>";
      action = "<cmd>close<cr>";
      options = {
        desc = "Hide Terminal";
      };
    }
    {
      mode = "t";
      key = "<leader>;q";
      action = "<cmd>close<cr>";
      options = {
        desc = "Close Terminal";
      };
    }
  ];
}
