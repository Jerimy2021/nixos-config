local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ["<C-h>"] = "which_key"
      }
    }
  }
})

-- Mapas de teclas
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope: Buscar archivos" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep,   { desc = "Telescope: Buscar texto (grep)" })
vim.keymap.set("n", "<leader>fb", builtin.buffers,     { desc = "Telescope: Buffers abiertos" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags,   { desc = "Telescope: Ayuda" })

vim.keymap.set("n", "<leader>j", "<cmd>Telescope jumplist<CR>", { desc = "Jump list" })

