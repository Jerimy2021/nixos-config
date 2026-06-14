-- Setup Telescope dap extension
local ok_telescope, telescope = pcall(require, "telescope")
if ok_telescope then
    telescope.load_extension "dap"
end
