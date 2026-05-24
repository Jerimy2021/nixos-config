require("mason-lspconfig").setup({
      ensure_installed = { "jdtls", "pyright", "clangd", "lua_ls"},
      automatic_installation = true,
	  setup_handlers = {
		function(server_name)
			require("lspconfig")[server_name].setup({})
		end,
	  }
})
