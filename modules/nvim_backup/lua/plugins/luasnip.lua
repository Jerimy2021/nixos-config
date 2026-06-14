-- lua/plugins/luasnip.lua

require("luasnip").setup({
    history = true,
    update_events = "TextChanged,TextChangedI",
})
