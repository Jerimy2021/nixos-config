require("nvim-treesitter").setup({
    ensure_installed = { 
		"java",
		"python",
		"cpp",
		"c",
		"lua",
		"vim",
		"vimdoc",
		"javascript",
		"html",
		"c_sharp",
		"bash",
		"json",
		"query"
	},
    sync_install = false,
    highlight = { enable = true },
    indent = { enable = true },
})
