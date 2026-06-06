require("tokyonight").setup({
  style = "night",
  transparent = true,
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
    functions = { bold = true },
    variables = {},
    sidebars = "transparent",
    floats = "transparent",
  },
  on_highlights = function(hl, c)
    hl.SignColumn = { bg = "NONE" }
    hl.LineNr = { fg = c.dark5, bg = "NONE" }
    hl.CursorLineNr = { fg = c.warning, bold = true }
    hl.TelescopeNormal = { bg = "NONE" }
    hl.TelescopeBorder = { fg = c.blue, bg = "NONE" }
  end,
})

vim.cmd("colorscheme tokyonight")
