return {
    "seblyng/roslyn.nvim",
    ft = "cs",
    opts = {
        cmd = { "Microsoft.CodeAnalysis.LanguageServer" },
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        settings = {
            ["csharp|vb"] = {
                formatting = { enable = true },
            },
        },
    },
    config = function(_, opts)
        require("roslyn").setup(opts)
    end,
}

