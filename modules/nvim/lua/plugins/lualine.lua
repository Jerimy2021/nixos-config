-- Archivo: plugins/lualine.lua
require('lualine').setup({
  options = {
    -- Cámbialo a: 'gruvbox', 'tokyonight', o 'auto' (para cyberdream)
    theme = 'gruvbox', 
    component_separators = { left = '│', right = '│' },
    section_separators = { left = '', right = '' },
    globalstatus = true,
  },
})
