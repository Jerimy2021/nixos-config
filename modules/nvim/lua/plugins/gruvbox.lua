require("gruvbox").setup({
  contrast = "hard",
  transparent_mode = true,
  italic = {
    strings = true,
    comments = true,
    operators = false,
    folds = true,
  },
})

-- Le decimos a Neovim que aplique el tema inmediatamente
--vim.cmd("colorscheme gruvbox")
