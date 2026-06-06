require("gruvbox").setup({
  contrast = "hard",
  transparent_mode = true,
  terminal_colors = true,
  italic = {
    strings = true,
    comments = true,
    operators = false,
    folds = true,
  },
  overrides = {
    SignColumn = { bg = "NONE" },
    Keyword = { fg = "#fb4934", bold = true },  -- Rojo vibrante intenso
    Function = { fg = "#b8bb26", bold = true }, -- Verde puro y brillante
    String = { fg = "#fabd2f", italic = true }, -- Amarillo dorado
    Type = { fg = "#83a598", bold = true },     -- Azul claro
  },
})

-- vim.cmd("colorscheme gruvbox")
