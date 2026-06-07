require("nvim-treesitter.configs").setup({
    ensure_installed = { 
        "java", "python", "cpp", "c", "lua", "vim", 
        "vimdoc", "javascript", "html", "c_sharp", 
        "bash", "json", "query" 
    },
    
    sync_install = false,
    auto_install = true,
    
    highlight = { 
        enable = true, 
        additional_vim_regex_highlighting = false,
    },
    
    indent = { enable = true },
})
