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
    -- 1. INTERFAZ Y BORDES
    SignColumn = { bg = "NONE" },
    TelescopeNormal = { bg = "NONE" },
    TelescopeBorder = { fg = "#a89984", bg = "NONE" },
    
    -- 2. SINTAXIS BASE Y PALABRAS CLAVE DETALLADAS
    Keyword = { fg = "#fb4934", bold = true, italic = true }, -- Rojo vibrante intenso
    ["@keyword.modifier"] = { fg = "#fb4934", bold = true, italic = true },
    ["@keyword.coroutine"] = { fg = "#fb4934", bold = true, italic = true },
    ["@keyword.exception"] = { fg = "#fb4934", bold = true, italic = true },
    ["@keyword.return"] = { fg = "#fb4934", bold = true, italic = true },
    ["@keyword.operator"] = { fg = "#fb4934", bold = true, italic = true },
    String = { fg = "#fabd2f", italic = true },               -- Amarillo dorado
    
    -- 3. MAGIA SEMÁNTICA (Reglas universales)
    ["@variable"] = { fg = "#ebdbb2" },                               -- Variables base
    ["@property"] = { fg = "#fe8019", italic = true },                -- Atributos (Naranja)
    ["@variable.member"] = { fg = "#fe8019", italic = true },         -- Atributos (Fallback)
    
    ["@function"] = { fg = "#b8bb26", bold = true },                  -- Funciones declaradas
    ["@function.call"] = { fg = "#b8bb26", bold = true },             -- Funciones ejecutadas
    ["@method.call"] = { fg = "#b8bb26", bold = true },               -- Métodos ejecutados
    
    ["@type"] = { fg = "#83a598", bold = true },                      -- Clases y Tipos
    ["@constructor"] = { fg = "#83a598", bold = true },               -- Constructores
    ["@parameter"] = { fg = "#d3869b", italic = true },               -- Parámetros (Púrpura)
    
    -- 4. EL JEFE FINAL: FORZAR AL LSP DE C#
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.method"] = { link = "@function" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.variable"] = { link = "@variable" },
    ["@lsp.type.parameter"] = { link = "@parameter" },
  },
})

-- vim.cmd("colorscheme gruvbox")
