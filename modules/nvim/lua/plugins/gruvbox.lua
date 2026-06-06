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
    
    -- 2. SINTAXIS BASE
    Keyword = { fg = "#fb4934", bold = true, italic = true }, -- Rojo vibrante intenso
    String = { fg = "#fabd2f", italic = true },               -- Amarillo dorado
    
    -- 3. MAGIA SEMÁNTICA (Reglas universales)
    ["@variable"] = { fg = "#ebdbb2" },                               -- Variables base (Blanco/Crema)
    ["@property"] = { fg = "#fe8019", italic = true },                -- Atributos (Naranja)
    ["@variable.member"] = { fg = "#fe8019", italic = true },         -- Atributos (Fallback)
    
    ["@function"] = { fg = "#b8bb26", bold = true },                  -- Funciones declaradas (Verde puro)
    ["@function.call"] = { fg = "#b8bb26", bold = true },             -- Funciones ejecutadas (Verde puro)
    ["@method.call"] = { fg = "#b8bb26", bold = true },               -- Métodos ejecutados (Verde puro)
    
    ["@type"] = { fg = "#83a598", bold = true },                      -- Clases y Tipos (Azul claro)
    ["@constructor"] = { fg = "#83a598", bold = true },               -- Constructores (Azul claro)
    ["@parameter"] = { fg = "#d3869b", italic = true },               -- Parámetros (Púrpura)
  },
})

-- vim.cmd("colorscheme gruvbox") -- Descomenta para probar
