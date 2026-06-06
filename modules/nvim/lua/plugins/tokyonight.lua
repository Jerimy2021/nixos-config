require("tokyonight").setup({
  style = "night",
  transparent = true,
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true, bold = true },
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
    
    hl.Keyword = { fg = c.magenta, bold = true, italic = true }
    hl.Function = { fg = c.cyan, bold = true }
    hl.String = { fg = c.green1, italic = true }
    hl.Type = { fg = c.blue1, bold = true }
  end,
})

-- vim.cmd("colorscheme tokyonight")
