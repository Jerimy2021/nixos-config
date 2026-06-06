require("lsp_signature").setup({
  bind = true, -- Habilita atajos internos
  floating_window = true, -- Muestra la cajita flotante sobre el código
  floating_window_above_cur_line = true, -- Intenta ponerla arriba para no tapar tu código
  hint_enable = true, -- Muestra un pequeño texto virtual al lado del cursor también
  hint_prefix = "🐱", -- Un icono divertido (puedes cambiarlo a "💡", ""🐼" ,"☯"  o "👉")
  handler_opts = {
    border = "rounded" -- Bordes elegantes para la ventana
  },
  transparency = 10, -- Ligera transparencia para que haga match con tu terminal
  zindex = 200, -- Asegura que la ventana flote por encima de otras
})
