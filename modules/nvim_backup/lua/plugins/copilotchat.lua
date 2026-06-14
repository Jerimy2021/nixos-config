local chat = require("CopilotChat")

chat.setup({
  window = {
    layout = 'float', -- Puedes cambiarlo a 'vertical' si prefieres que salga a la derecha
    width = 0.8,      -- Ocupa el 80% del ancho de la pantalla
    height = 0.8,     -- Ocupa el 80% del alto
    border = 'rounded',
  },
  -- Configuración para que entienda español por defecto al hacer acciones
  prompts = {
    Explain = {
      prompt = '/COPILOT_EXPLAIN Explícame cómo funciona este código línea por línea en español.',
    },
    Optimize = {
      prompt = '/COPILOT_REFACTOR Optimiza este código para mejorar su rendimiento y legibilidad. Responde en español.',
    },
    Tests = {
      prompt = '/COPILOT_TESTS Genera pruebas unitarias para este código. Responde en español.',
    },
  },
})
