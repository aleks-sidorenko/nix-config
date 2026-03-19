{ config, lib, ... }:
{
  plugins.copilot-chat = {
    inherit (config.ai.copilot) enable;

    lazyLoad.enable = true;
    lazyLoad.settings.cmd = [
      "CopilotChat"
      "CopilotChatAgents"
      "CopilotChatLoad"
      "CopilotChatModels"
      "CopilotChatOpen"
      "CopilotChatPrompts"
      "CopilotChatToggle"
    ];
  };

  plugins.which-key.settings.spec = lib.optionals config.ai.copilot.enable [
    {
      __unkeyed-1 = "<leader>aC";
      group = "Copilot";
      icon = "";
    }
  ];

  keymaps = lib.mkIf config.ai.copilot.enable [
    {
      mode = "n";
      key = "<leader>aCa";
      action = "<cmd>CopilotChatAgents<CR>";
      options.desc = "List Available Agents";
    }
    {
      mode = "n";
      key = "<leader>aCc";
      action = "<cmd>CopilotChatClose<CR>";
      options.desc = "Close Chat";
    }
    {
      mode = "n";
      key = "<leader>aCd";
      action = "<cmd>CopilotChatDocs<CR>";
      options.desc = "Add Documentation";
    }
    {
      mode = "n";
      key = "<leader>aCe";
      action = "<cmd>CopilotChatExplain<CR>";
      options.desc = "Explain Code";
    }
    {
      mode = "n";
      key = "<leader>aCl";
      action = "<cmd>CopilotChatLoad<CR>";
      options.desc = "Load Chat History";
    }
    {
      mode = "n";
      key = "<leader>aCm";
      action = "<cmd>CopilotChatModels<CR>";
      options.desc = "List Available Models";
    }
    {
      mode = "n";
      key = "<leader>aCo";
      action = "<cmd>CopilotChatOpen<CR>";
      options.desc = "Open Chat";
    }
    {
      mode = "n";
      key = "<leader>aCP";
      action = "<cmd>CopilotChatPrompts<CR>";
      options.desc = "Select Prompt";
    }
    {
      mode = "n";
      key = "<leader>aCq";
      action.__raw = ''
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end
      '';
      options.desc = "Quick Chat";
    }
    {
      mode = "n";
      key = "<leader>aCr";
      action = "<cmd>CopilotChatReset<CR>";
      options.desc = "Reset Chat";
    }
    {
      mode = "n";
      key = "<leader>aCR";
      action = "<cmd>CopilotChatReview<CR>";
      options.desc = "Review Code";
    }
    {
      mode = "n";
      key = "<leader>aCs";
      action = "<cmd>CopilotChatStop<CR>";
      options.desc = "Stop Chat";
    }
    {
      mode = "n";
      key = "<leader>aCS";
      action = "<cmd>CopilotChatSave<CR>";
      options.desc = "Save Chat";
    }
    {
      mode = "n";
      key = "<leader>aCt";
      action = "<cmd>CopilotChatToggle<CR>";
      options.desc = "Toggle Chat Window";
    }
    {
      mode = "n";
      key = "<leader>aCT";
      action = "<cmd>CopilotChatTests<CR>";
      options.desc = "Generate Tests";
    }
  ];
}
