require("cyberdream").setup({
    transparent = true,
    italic_comments = true,
    correct_plugin_colors = true,
    terminal_colors = true,
    theme = {
        variant = "default",
        highlights = {
            SignColumn = { bg = "NONE" }, 
            LineNr = { fg = "#5c6370", bg = "NONE" },
            CursorLineNr = { fg = "#00ffc8", bold = true, bg = "NONE" },
            TelescopeNormal = { bg = "NONE" },
            TelescopeBorder = { fg = "#3c4048", bg = "NONE" },
            
            Keyword = { fg = "#ff5ea0", bold = true, italic = true }, -- Rosa Neón
            Function = { fg = "#00ffc8", bold = true },               -- Cyan Neón
            String = { fg = "#f1fa8c", italic = true },               -- Amarillo Eléctrico
            Type = { fg = "#bd93f9", bold = true },                   -- Púrpura
        },
    },
})

vim.cmd("colorscheme cyberdream")
