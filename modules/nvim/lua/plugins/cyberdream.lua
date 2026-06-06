-- Archivo: plugins/cyberdream.lua
require("cyberdream").setup({
    transparent = true,
    italic_comments = true,
    correct_plugin_colors = true,
    terminal_colors = true,
    theme = {
        variant = "default",
        highlights = {
            -- 1. INTERFAZ Y BORDES
            SignColumn = { bg = "NONE" }, 
            LineNr = { fg = "#5c6370", bg = "NONE" },
            CursorLineNr = { fg = "#00ffc8", bold = true, bg = "NONE" },
            TelescopeNormal = { bg = "NONE" },
            TelescopeBorder = { fg = "#3c4048", bg = "NONE" },
            
            -- 2. SINTAXIS BASE
            Keyword = { fg = "#ff5ea0", bold = true, italic = true }, -- Rosa Neón (if, var, public, return)
            String = { fg = "#f1fa8c", italic = true },               -- Amarillo Eléctrico ("textos")
            
            -- 3. MAGIA SEMÁNTICA (Reglas universales para todos los lenguajes)
            ["@variable"] = { fg = "#ffffff" },                               -- Variables base (Blanco)
            ["@property"] = { fg = "#ffb86c", italic = true },                -- Atributos (Naranja claro)
            ["@variable.member"] = { fg = "#ffb86c", italic = true },         -- Atributos (Fallback)
            
            ["@function"] = { fg = "#00ffc8", bold = true },                  -- Funciones declaradas (Cyan)
            ["@function.call"] = { fg = "#00ffc8", bold = true },             -- Funciones ejecutadas (Cyan)
            ["@method.call"] = { fg = "#00ffc8", bold = true },               -- Métodos ejecutados (Cyan)
            
            ["@type"] = { fg = "#bd93f9", bold = true },                      -- Clases y Tipos (Púrpura)
            ["@constructor"] = { fg = "#bd93f9", bold = true },               -- Constructores (Púrpura)
            ["@parameter"] = { fg = "#8be9fd", italic = true },               -- Parámetros dentro de paréntesis
        },
    },
})

vim.cmd("colorscheme cyberdream")
