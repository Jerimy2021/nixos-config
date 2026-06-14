-- lua/plugins/nvim-cmp.lua
local cmp = require("cmp")
cmp.setup({
    snippet = {
        expand = function(args)
            require("luasnip").lsp_expand(args.body) -- Usar LuaSnip para snippets
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(), -- Mostrar autocompletado
        ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Confirmar selección
        ["<Tab>"] = cmp.mapping.select_next_item(), -- Navegar al siguiente ítem
        ["<S-Tab>"] = cmp.mapping.select_prev_item(), -- Navegar al ítem anterior
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" }, -- Autocompletado del LSP
		{ name = "copilot" },  -- Autocompletado de copilot
        { name = "luasnip" },  -- Snippets desde LuaSnip
        { name = "buffer" },   -- Autocompletado desde el buffer actual
        { name = "path" },     -- Autocompletado para rutas de archivos
    }),
})
