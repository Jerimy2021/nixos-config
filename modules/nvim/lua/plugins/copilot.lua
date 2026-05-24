require("copilot").setup({
  panel = { 
    enabled = true 
  },
  suggestion = { 
    enabled = true,
    auto_trigger = true,
	keymap = {
      accept = "<Tab>",
      accept_line = false,
    },
  },
  filetypes = {
    python = false,
    cpp = false,
    c = false, 
    ["*"] = true,
  },
})
