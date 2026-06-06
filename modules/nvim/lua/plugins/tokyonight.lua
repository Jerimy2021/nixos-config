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
    -- 1. INTERFAZ Y CARPETAS
    hl.SignColumn = { bg = "NONE" }
    hl.LineNr = { fg = c.dark5, bg = "NONE" }
    hl.CursorLineNr = { fg = c.warning, bold = true }
    hl.TelescopeNormal = { bg = "NONE" }
    hl.TelescopeBorder = { fg = c.blue, bg = "NONE" }
    hl.Directory = { fg = c.cyan, bold = true } 
    hl.NvimTreeFolderIcon = { fg = c.blue1 }    
    
    -- 2. SINTAXIS BASE
    hl.Keyword = { fg = c.magenta, bold = true, italic = true }
    hl.String = { fg = c.green1, italic = true }
    
    -- 3. MAGIA SEMÁNTICA (Reglas universales)
    hl["@variable"] = { fg = c.fg }                                -- Variables base (Color normal del tema)
    hl["@property"] = { fg = c.yellow, italic = true }             -- Atributos (Amarillo)
    hl["@variable.member"] = { fg = c.yellow, italic = true }      -- Atributos (Fallback)
    
    hl["@function"] = { fg = c.cyan, bold = true }                 -- Funciones
    hl["@function.call"] = { fg = c.cyan, bold = true }            -- Funciones ejecutadas
    hl["@method.call"] = { fg = c.cyan, bold = true }              -- Métodos ejecutados
    
    hl["@type"] = { fg = c.blue1, bold = true }                    -- Clases y Tipos (Azul brillante)
    hl["@constructor"] = { fg = c.blue1, bold = true }             -- Constructores
    hl["@parameter"] = { fg = c.orange, italic = true }            -- Parámetros (Naranja)
  end,
})

-- vim.cmd("colorscheme tokyonight") -- Descomenta para probar
