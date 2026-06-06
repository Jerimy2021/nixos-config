-- Archivo: plugins/cyberdream.lua
require("cyberdream").setup({
    transparent = true,
    italic_comments = true,
    correct_plugin_colors = true,
    
    theme = {
        variant = "default",
        highlights = {
            SignColumn = { bg = "NONE" }, 
            
            LineNr = { fg = "#5c6370", bg = "NONE" },
            CursorLineNr = { fg = "#00ffc8", bold = true, bg = "NONE" },
            
            TelescopeNormal = { bg = "NONE" },
            TelescopeBorder = { fg = "#3c4048", bg = "NONE" },
        },
    },
})

-- Aplicar el esquema inmediatamente
vim.cmd("colorscheme cyberdream")
