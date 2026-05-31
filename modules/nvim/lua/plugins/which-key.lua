local wk = require("which-key")

-- =============================================================================
-- CONFIGURACIÓN VISUAL
-- =============================================================================
wk.setup({
  preset = "modern", -- Cambia el diseño a uno más moderno, limpio y alineado
  delay = 500, 
  icons = {
    breadcrumb = "»",
    separator = " ➜ ", -- Añadimos espacios para que el texto respire
    group = "✦ ",      -- Un símbolo más elegante que el simple '+'
  },
  win = {
    border = "rounded",       -- Bordes redondeados para la ventana flotante
    padding = { 2, 2, 2, 2 }, -- Espaciado interno para que no se vea apretado
  },
})

-- =============================================================================
-- REGISTRO DE ATAJOS ESTRUCTURADOS
-- =============================================================================
wk.add({

  -- ---------------------------------------------------------------------------
  -- 1. ATAJOS RÁPIDOS EN LA RAÍZ
  -- ---------------------------------------------------------------------------
  -- Al documentar tus atajos sueltos aquí, Which-Key les dará formato y los alineará.
  { "<leader>1", desc = "Ir al Archivo 1 (Harpoon) 📌" },
  { "<leader>2", desc = "Ir al Archivo 2 (Harpoon) 📌" },
  { "<leader>3", desc = "Ir al Archivo 3 (Harpoon) 📌" },
  { "<leader>4", desc = "Ir al Archivo 4 (Harpoon) 📌" },
  
  { 
    "<leader>V", 
    function()
        local file_extension = vim.fn.expand('%:e')
        local image_extensions = { 'png', 'jpg', 'jpeg', 'gif', 'webp' }
        local is_image = false
        for _, ext in ipairs(image_extensions) do
            if file_extension:lower() == ext then
                is_image = true
                break
            end
        end
        if is_image then
            vim.cmd('silent !feh ' .. vim.fn.shellescape(vim.fn.expand('%')) .. ' &')
        else
            vim.notify('El archivo actual no parece ser una imagen compatible.', vim.log.levels.WARN)
        end
    end, 
    desc = "Ver imagen actual (feh) 🖼️" 
  },
  { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Abrir Explorador (NvimTree) 📂" },
  { "<leader>V", desc = "Ver imagen actual (feh) 🖼️" },
  { "<leader>j", desc = "Saltar (Jump List) 🦘" },

  -- Tienes plugins que auto-crean <leader>t y <leader>v en segundo plano.
  -- Les damos un nombre aquí para que no salgan como "+3 keymaps" sin contexto.
  { "<leader>t", group = "Terminal / Tests 🖥️" },
  { "<leader>v", group = "Visual / Selecciones 🖱️" },
  {
    mode = { "x" }, -- Aplica solo cuando seleccionas texto
    { "<leader>p", '"_dP', desc = "Pegar sin sobreescribir portapapeles 📋" },
  },


  -- ---------------------------------------------------------------------------
  -- 2. MENÚS DESPLEGABLES (Presionar <leader> + Letra de categoría)
  -- ---------------------------------------------------------------------------
  -- Terminal
  { "<leader>t", group = "Terminal 🖥️" },
  { "<leader>tt", "<cmd>below terminal<CR>", desc = "Terminal abajo" },
  { "<leader>ta", "<cmd>above terminal<CR>", desc = "Terminal arriba" },
  { "<leader>tv", "<cmd>vertical terminal<CR>", desc = "Terminal vertical" },
  
  -- Copilot 
  { "<leader>a", group = "Copilot / Inteligencia IA 🤖" },
  { "<leader>at", "<cmd>Copilot toggle<cr>", desc = "Prender/Apagar Autocompletado" },
  { "<leader>ap", "<cmd>Copilot panel<cr>", desc = "Abrir Panel de Sugerencias" },
  { "<leader>ac", "<cmd>CopilotChatToggle<cr>", desc = "Abrir/Cerrar Chat" },
  { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "Explicar código seleccionado" },
  { "<leader>ag", "<cmd>CopilotChat Commit<cr>", desc = "Generar Mensaje de Commit" },

  { "<leader>c", group = "Competitivo / Leetcode 🏆" },
  { "<leader>cl", "<cmd>Leet<cr>", desc = "Abrir entorno LeetCode" },
  { "<leader>cr", "<cmd>CompetiTest run<cr>", desc = "Correr Casos Locales" },
  { "<leader>ca", "<cmd>CompetiTest add_testcase<cr>", desc = "Añadir Caso de prueba" },
  { "<leader>ce", "<cmd>CompetiTest edit_testcase<cr>", desc = "Editar Caso de prueba" },
  { "<leader>cd", "<cmd>CompetiTest receive testcases<cr>", desc = "Descargar Casos" },

  { "<leader>d", group = "Debugging (DAP) 🪲" },
  { "<leader>db", "<cmd>DapToggleBreakpoint<cr>", desc = "Poner/Quitar Breakpoint" },
  { "<leader>di", "<cmd>DapStepInto<cr>", desc = "Entrar a la función" },
  { "<leader>do", "<cmd>DapStepOver<cr>", desc = "Pasar siguiente línea" },
  { "<leader>dt", "<cmd>DapTerminate<cr>", desc = "Detener Debugger" },
  { "<leader>du", function() require("dapui").toggle() end, desc = "Paneles de Variables" },
  { "<leader>dv", "<cmd>Telescope dap variables<cr>", desc = "Buscar Variables" },
  { "<leader>df", "<cmd>Telescope dap frames<cr>", desc = "Ver Pila de llamadas" },

  { "<leader>f", group = "Archivos / Búsqueda 🔍" },
  { "<leader>fe", "<cmd>NvimTreeToggle<cr>", desc = "Explorador Lateral" },
  { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Buscar por nombre" },
  { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Buscar Palabra" },
  { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Ver Buffers" },
  { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Buscar Ayuda" },

  { "<leader>h", group = "Opciones Harpoon ⚓" },
  { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Marcar archivo" },
  { "<leader>hm", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Abrir Menú Harpoon" },

  { "<leader>l", group = "Lenguaje / LSP 🧠" },
  { "<leader>lf", function() vim.lsp.buf.format() end, desc = "Formatear Código (Prettier/LSP) ✨" },
  { "<leader>lr", function() vim.lsp.buf.rename() end, desc = "Renombrar Variable" },
  { "<leader>la", function() vim.lsp.buf.code_action() end, desc = "Acciones de Código" },
  { "<leader>ld", "<cmd>Telescope diagnostics<cr>", desc = "Ver Errores" },
  { "<leader>li", "<cmd>LspInfo<cr>", desc = "Estado de Servidores" },
  { "<leader>lg", "<cmd>Telescope lsp_definitions<cr>", desc = "Ir a Definición" },

  { "<leader>s", group = "Sistema / Plugins 🛠️" },
  { "<leader>sm", "<cmd>Mason<cr>", desc = "Mason (LSP)" },
  { "<leader>sl", "<cmd>Lazy<cr>", desc = "Lazy (Plugins)" },

})
