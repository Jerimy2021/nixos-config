require('lualine').setup({
  options = {
    theme = 'tokyonight', -- Lualine adopta los colores del tema
    component_separators = { left = '│', right = '│' },
    section_separators = { left = '', right = '' },
    globalstatus = true,
  },
})
