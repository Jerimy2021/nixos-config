return {

  -- =============================================================================
  -- 1. SINTAXIS Y RESALTADO DE CÓDIGO [AUTOMÁTICO]
  -- ¿Qué hace?: Analiza el código para darle colores ultra-precisos según el lenguaje.
  -- ¿Qué va aquí?: Plugins de colores para paréntesis, cerrar etiquetas HTML, etc.
  -- =============================================================================
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },


  -- =============================================================================
  -- 2. ENTORNO LSP Y SERVIDORES (El "Cerebro" de Neovim) [AUTOMÁTICO / INTERACTIVO]
  -- ¿Qué hace?: Instala y conecta los compiladores y analizadores para que Neovim
  --             entienda tus variables, detecte errores y complete código.
  -- ¿Qué va aquí?: Herramientas de formateo (Prettier, Black), linters o nuevos LSPs.
  -- =============================================================================
  -- Administrador para instalar LSPs, formateadores y debuggers 
  { "williamboman/mason.nvim", lazy = false },
  -- Conector entre Mason y la configuración nativa de Neovim
  { "williamboman/mason-lspconfig.nvim" },
  -- La configuración base para que Neovim hable con los lenguajes
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspInstall", "LspStart" }, 
    event = { "BufReadPre", "BufNewFile" } 
  },
  -- Soporte avanzado y específico para Java (LSP de Java)
  { "mfussenegger/nvim-jdtls" },
  -- Soporte avanzado y específico para C# y .NET (LSP de Roslyn)
  { "seblyng/roslyn.nvim", lazy = true, ft = "cs" },


  -- =============================================================================
  -- 3. AUTOCOMPLETADO, SNIPPETS e INTELIGENCIA ARTIFICIAL [AUTOMÁTICO]
  -- ¿Qué hace?: Abre la ventanita flotante flotante mientras escribes y mete código IA.
  -- ¿Qué va aquí?: Nuevas fuentes de autocompletado (emojis, comandos de terminal).
  -- =============================================================================
  -- El motor principal de autocompletado
  { "hrsh7th/nvim-cmp", event = "InsertEnter" },
  -- Fuentes para que el autocompletado sepa de dónde sacar palabras:
  { "hrsh7th/cmp-nvim-lsp" }, -- Saca sugerencias del LSP
  { "hrsh7th/cmp-buffer" },   -- Saca sugerencias de palabras que ya escribiste en el archivo
  { "hrsh7th/cmp-path" },     -- Saca sugerencias de rutas de carpetas
  { "rcarriga/cmp-dap" },     -- Saca sugerencias dentro de la consola de Debugging
  -- Motor de plantillas de código rápido (Snippets)
  { "L3MON4D3/LuaSnip" },
  -- GitHub Copilot
  { "zbirenbaum/copilot.lua" },
  -- El chat interactivo de copilot
  { "CopilotC-Nvim/CopilotChat.nvim", 
  	dependencies = { 
		{ "zbirenbaum/copilot.lua" },
		{ "nvim-lua/plenary.nvim" },
	},
	build = "make tiktoken",},

  -- =============================================================================
  -- 4. NAVEGACIÓN, BÚSQUEDA Y EXPLORADOR [INTERACTIVO - USA WHICH-KEY]
  -- ¿Qué hace?: Te ayuda a moverte entre archivos y buscar texto a la velocidad de la luz.
  -- ¿Qué va aquí?: Plugins de búsqueda de texto alternativos, gestores de proyectos.
  -- =============================================================================
  -- El buscador universal (Fuzzy Finder) para encontrar cualquier cosa
  { 
    "nvim-telescope/telescope.nvim", 
    tag = "0.1.8", 
    dependencies = { "nvim-lua/plenary.nvim" } 
  },
  -- Explorador de archivos lateral en forma de árbol
  { 
    "nvim-tree/nvim-tree.lua", 
    version = "*", 
    lazy = false, 
    dependencies = { "nvim-tree/nvim-web-devicons" }
  },
  -- Harpoon: Para marcar tus 4 archivos principales y saltar entre ellos al instante
  { 
    "ThePrimeagen/harpoon", 
    branch = "harpoon2", 
    requires = {"nvim-lua/plenary.nvim"}
  },


  -- =============================================================================
  -- 5. ENTORNO DE DEPURACIÓN (Debugging / DAP) [INTERACTIVO - USA WHICH-KEY]
  -- ¿Qué hace?: Te permite pausar la ejecución de tu código, poner breakpoints
  --             y ver el valor de las variables en tiempo real.
  -- ¿Qué va aquí?: Adaptadores de debug específicos para Python, C++, Node, etc.
  -- =============================================================================
  -- El motor principal de Debug nativo de Neovim
  { "mfussenegger/nvim-dap" },
  -- Permite a Mason descargar e instalar los debuggers en el sistema
  { "jay-babu/mason-nvim-dap.nvim" },
  -- La increíble interfaz gráfica (paneles flotantes, variables, consola) para el debug
  { 
    "rcarriga/nvim-dap-ui", 
    requires = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"} 
  },
  -- Escribe los valores de tus variables con texto flotante al lado de tu código
  { "theHamsta/nvim-dap-virtual-text" },
  -- Permite buscar y controlar tus sesiones de debug usando Telescope
  { "nvim-telescope/telescope-dap.nvim" },


  -- =============================================================================
  -- 6. PROGRAMACIÓN COMPETITIVA [INTERACTIVO - USA WHICH-KEY]
  -- ¿Qué hace?: Integra plataformas de ejercicios de código dentro de tu editor.
  -- ¿Qué va aquí?: Plugins similares para Codeforces,Competitive Companion, etc.
  -- =============================================================================
  -- Ejecuta casos de prueba locales de forma automatizada y ordenada
  { "xeluxee/competitest.nvim", dependencies = "MunifTanjim/nui.nvim" },
  -- Trae todos los problemas y testing de la plataforma LeetCode a Neovim
  { 
    "kawre/leetcode.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    }
  },


  -- =============================================================================
  -- 7. UTILIDADES Y MENÚS DE ATAJOS [INTERACTIVO / MEMORIA]
  -- ¿Qué hace?: Te da menús interactivos o atajos rápidos para facilitarte la vida.
  -- ¿Qué va aquí?: Plugins de Git (Gitsigns), gestores de sesiones, etc.
  -- =============================================================================
  -- El plugin que estamos configurando para recordarte cada atajo de teclado
  { "folke/which-key.nvim" },
  -- Comenta líneas de código de forma súper rápida (Atajos nativos: gcc o gc)
  { "numToStr/Comment.nvim" },
  -- Te permite crear sub-menús de atajos complejos (ideal para flujos específicos)
  { "anuvyklack/hydra.nvim" },
  -- En la sección 7 de tu lista de plugins:
  { "lewis6991/gitsigns.nvim" },


  -- =============================================================================
  -- 8. INTERFAZ VISUAL, ESTÉTICA Y TEMAS [VISUAL - CONFIGURACIÓN ÚNICA]
  -- ¿Qué hace?: Hace que Neovim se vea hermoso, agrega la barra inferior y los iconos.
  -- ¿Qué va aquí?: Líneas de indentación, barras de pestañas superiores (bufferlines).
  -- =============================================================================
  { "ellisonleao/gruvbox.nvim", priority = 1000 }, -- Tema Retro Gruvbox
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 }, -- Tema Moderno TokyoNight
  { "scottmckendry/cyberdream.nvim", lazy = false, priority = 1000 }, -- Tema CyberDream 
  -- Barra informativa inferior
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },


  -- =============================================================================
  -- 9. LIBRERÍAS DE SOPORTE (¡NO TOCAR!) [SISTEMA]
  -- ¿Qué hace?: Son dependencias internas de código que los creadores de otros
  --             plugins usan para poder dibujar ventanas o gestionar tareas.
  -- ¿Qué va aquí?: Solo agregas algo aquí si un plugin de GitHub te lo pide como "dependency".
  -- =============================================================================
  { "nvim-lua/plenary.nvim" },       -- La usa Telescope y Harpoon
  { "MunifTanjim/nui.nvim" },         -- La usa LeetCode y Competitest
  { "nvim-neotest/nvim-nio" },       -- La usa Dap-UI
  { "nvim-tree/nvim-web-devicons" }, -- Iconos del sistema compartidos por varios plugins

}
