-- Archivo: plugins/tokyonight.lua
require("tokyonight").setup({
  style = "night",        -- Variante con colores vivos y alto contraste
  transparent = true,     -- Absorbe la transparencia exacta de Kitty
  terminal_colors = true,
  styles = {
    -- Estilos de fuente dinámicos para un look Senior
    comments = { italic = true },
    keywords = { italic = true },
    functions = { bold = true },
    variables = {},
    -- Aseguramos que los paneles laterales también sean transparentes
    sidebars = "transparent",
    floats = "transparent",
  },
  -- Forzamos transparencia extra en elementos molestos
  on_highlights = function(hl, c)
    hl.SignColumn = { bg = "NONE" }
    hl.LineNr = { fg = c.dark5, bg = "NONE" }
    hl.CursorLineNr = { fg = c.warning, bold = true }
    hl.TelescopeNormal = { bg = "NONE" }
    hl.TelescopeBorder = { fg = c.blue, bg = "NONE" }
  end,
})

-- Aplicar el esquema inmediatamente
vim.cmd("colorscheme tokyonight")
