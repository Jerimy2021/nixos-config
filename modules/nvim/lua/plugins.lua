
-- Inicialización de lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup("pluginlist", {
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
})


-- Cargar configuraciones de plugins desde archivos separados
require("plugins.treesitter")       -- Configuración de Treesitter
require("plugins.mason")            -- Configuración de Mason
require("plugins.nvim-cmp")         -- Configuración de nvim-cmp
require("plugins.lspconfig")        -- Configuración de LSP
require("plugins.telescope")     	-- Configuración de Telescope
-- require("plugins.comment")       -- Configuración de Comment.nvim
require("plugins.gruvbox")       -- Configuración de Gruvbox
require("plugins.tokyonight")       -- Configuracion de tokyonight
require("plugins.cyberdream")   	-- Configuración de Cyberdream
require("plugins.lualine")          -- Configuración de Lualine
require("plugins.nvim-tree")        -- Configuración de Nvim Tree
require("plugins.luasnip")          -- Configuracion de luasnip
require("plugins.competitest")      -- Configuración de competitest
require("plugins.nvim-dap-ui")		-- Configuracion de nvim-dap-ui
require("plugins.cmp-dap")			-- Configuracion de cmp-dap
require("plugins.dap")				-- Configuracion de dap
require("plugins.hydra")			-- Configuracion de hydra
require("plugins.mason-nvim-dap")   -- Configuracion de mason-nvim-dap
require("plugins.nvim-dap-ui")		-- Configuracion de nvim-dap-ui
require("plugins.nvim-dap-virtual-text") -- Configuracion de nvim-dap-virtual-text
require("plugins.telescope-dap")	-- Configuracion de telescope-dap
require("plugins.harpoon")			-- Configuracion de harpoon
require("plugins.leetcode")			-- Configuracion de leetcode
require("plugins.copilot") 			-- Configuracion de copilot
require("plugins.copilotchat")		-- Configuracion de copilot-chat
require("plugins.which-key")		-- Configuracion de which-key
require("plugins.gitsigns")			-- Configuracion de gitsigns
