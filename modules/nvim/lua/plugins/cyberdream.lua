require("cyberdream").setup({
    transparent = true,
    italic_comments = true,
    terminal_colors = true,
})

vim.cmd("colorscheme cyberdream")

local custom_colors = {
    -- 1. INTERFAZ Y BORDES
    SignColumn = { bg = "NONE" }, 
    LineNr = { fg = "#5c6370", bg = "NONE" },
    CursorLineNr = { fg = "#00ffc8", bold = true, bg = "NONE" },
    TelescopeNormal = { bg = "NONE" },
    TelescopeBorder = { fg = "#3c4048", bg = "NONE" },
    
    -- 2. PALABRAS CLAVE (Rosa Neón Absoluto)
    Keyword = { fg = "#ff5ea0", bold = true, italic = true },
    ["@keyword"] = { fg = "#ff5ea0", bold = true, italic = true },
    ["@keyword.modifier"] = { fg = "#ff5ea0", bold = true, italic = true }, -- public, private, protected
    ["@keyword.coroutine"] = { fg = "#ff5ea0", bold = true, italic = true }, -- async, await
    ["@keyword.exception"] = { fg = "#ff5ea0", bold = true, italic = true }, -- throw, try, catch
    ["@keyword.return"] = { fg = "#ff5ea0", bold = true, italic = true }, -- return
    ["@keyword.operator"] = { fg = "#ff5ea0", bold = true, italic = true }, -- new, typeof
    
    -- 3. TEXTOS Y VARIABLES (Reglas Universales)
    String = { fg = "#f1fa8c", italic = true },                       -- Textos (Amarillo)
    ["@variable"] = { fg = "#ffffff" },                               -- Variables base (Blanco)
    ["@property"] = { fg = "#ffb86c", italic = true },                -- Atributos (Naranja claro)
    
    -- 4. FUNCIONES Y CLASES
    ["@function"] = { fg = "#00ffc8", bold = true },                  -- Funciones (Cyan)
    ["@function.call"] = { fg = "#00ffc8", bold = true },             -- Funciones ejecutadas (Cyan)
    ["@method"] = { fg = "#00ffc8", bold = true },                    -- Métodos (Cyan)
    ["@method.call"] = { fg = "#00ffc8", bold = true },               -- Métodos ejecutados (Cyan)
    
    ["@type"] = { fg = "#bd93f9", bold = true },                      -- Clases y Tipos (Púrpura)
    ["@constructor"] = { fg = "#bd93f9", bold = true },               -- Constructores (Púrpura)
    ["@parameter"] = { fg = "#8be9fd", italic = true },               -- Parámetros (Celeste claro)

    -- ==========================================================
    -- 5. EL JEFE FINAL: LSP SEMANTIC TOKENS (C# Roslyn / Java)
    -- Obligamos al autocompletado a respetar los colores de arriba
    -- ==========================================================
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.method"] = { link = "@function" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.variable"] = { link = "@variable" },
    ["@lsp.type.parameter"] = { link = "@parameter" },
}

-- Bucle que inyecta todos estos colores en el núcleo de Neovim
for group, hl in pairs(custom_colors) do
    vim.api.nvim_set_hl(0, group, hl)
end
