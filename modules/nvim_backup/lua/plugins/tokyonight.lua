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
    
    -- 2. SINTAXIS BASE Y PALABRAS CLAVE DETALLADAS
    hl.Keyword = { fg = c.magenta, bold = true, italic = true }
    hl["@keyword.modifier"] = { fg = c.magenta, bold = true, italic = true } -- public, private
    hl["@keyword.coroutine"] = { fg = c.magenta, bold = true, italic = true } -- async, await
    hl["@keyword.exception"] = { fg = c.magenta, bold = true, italic = true } -- throw, try, catch
    hl["@keyword.return"] = { fg = c.magenta, bold = true, italic = true } -- return
    hl["@keyword.operator"] = { fg = c.magenta, bold = true, italic = true } -- new, typeof
    hl.String = { fg = c.green1, italic = true }
    
    -- 3. MAGIA SEMÁNTICA (Reglas universales)
    hl["@variable"] = { fg = c.fg }                                -- Variables base
    hl["@property"] = { fg = c.yellow, italic = true }             -- Atributos
    hl["@variable.member"] = { fg = c.yellow, italic = true }      -- Atributos (Fallback)
    
    hl["@function"] = { fg = c.cyan, bold = true }                 -- Funciones
    hl["@function.call"] = { fg = c.cyan, bold = true }            -- Funciones ejecutadas
    hl["@method.call"] = { fg = c.cyan, bold = true }              -- Métodos ejecutados
    
    hl["@type"] = { fg = c.blue1, bold = true }                    -- Clases y Tipos
    hl["@constructor"] = { fg = c.blue1, bold = true }             -- Constructores
    hl["@parameter"] = { fg = c.orange, italic = true }            -- Parámetros
    
    -- 4. EL JEFE FINAL: FORZAR AL LSP DE C#
    hl["@lsp.type.class"] = { link = "@type" }
    hl["@lsp.type.interface"] = { link = "@type" }
    hl["@lsp.type.method"] = { link = "@function" }
    hl["@lsp.type.property"] = { link = "@property" }
    hl["@lsp.type.variable"] = { link = "@variable" }
    hl["@lsp.type.parameter"] = { link = "@parameter" }
  end,
})

-- vim.cmd("colorscheme tokyonight")
