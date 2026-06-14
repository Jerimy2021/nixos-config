local lspconfig = require("lspconfig")

local capabilities = vim.tbl_deep_extend(

  "force",

  vim.lsp.protocol.make_client_capabilities(),

  require("cmp_nvim_lsp").default_capabilities()

)


-- Keymaps automáticos al adjuntar un cliente LSP

vim.api.nvim_create_autocmd("LspAttach", {

  desc = "LSP actions",

  callback = function(event)

    local opts = { buffer = event.buf }

    local map = vim.keymap.set

    map("n", "K", vim.lsp.buf.hover, opts)

    map("n", "gd", vim.lsp.buf.definition, opts)

    map("n", "gD", vim.lsp.buf.declaration, opts)

    map("n", "gi", vim.lsp.buf.implementation, opts)

    map("n", "go", vim.lsp.buf.type_definition, opts)

    map("n", "gr", vim.lsp.buf.references, opts)

    map("n", "gs", vim.lsp.buf.signature_help, opts)

    map("n", "<F2>", vim.lsp.buf.rename, opts)

    map({ "n", "x" }, "<F3>", function() vim.lsp.buf.format({ async = true }) end, opts)

    map("n", "<F4>", vim.lsp.buf.code_action, opts)

    map("n", "<leader>vd", vim.diagnostic.open_float, opts)

  end,

})


-- ===========================================

-- clangd LSP configuration (modern API)

-- ===========================================

vim.lsp.start({

  name = "clangd",

  cmd = {

    "clangd",

    "--background-index",

    "--clang-tidy",

    "--header-insertion=iwyu",

    "--query-driver=/nix/store/*/bin/gcc",

  },

  filetypes = { "c", "cpp", "objc", "objcpp" },


  root_dir = vim.fs.dirname(vim.fs.find({

    "compile_commands.json",

    "compile_flags.txt",

    ".git",

  }, { upward = true })[1]),


  capabilities = capabilities,


  init_options = {

    clangdFileStatus = true,

    fallbackFlags = {

      "-std=c++17",

      "-I/nix/store/62qjb50708fdhb4f2y7zxyqr1afir4fk-gcc-13.3.0/include/c++/13.3.0",

      "-I/nix/store/62qjb50708fdhb4f2y7zxyqr1afir4fk-gcc-13.3.0/include/c++/13.3.0/x86_64-unknown-linux-gnu",

      "-I/nix/store/62qjb50708fdhb4f2y7zxyqr1afir4fk-gcc-13.3.0/lib/gcc/x86_64-unknown-linux-gnu/13.3.0/include",

      "-I/nix/store/62qjb50708fdhb4f2y7zxyqr1afir4fk-gcc-13.3.0/include",

      "-I/nix/store/62qjb50708fdhb4f2y7zxyqr1afir4fk-gcc-13.3.0/lib/gcc/x86_64-unknown-linux-gnu/13.3.0/include-fixed",

      "-I/nix/store/lcxvgkg659vbvdq86mhxa599wn48f35c-glibc-2.40-36-dev/include",

    },

  },

})



-- 1. Configurar C# (OmniSharp)

lspconfig.omnisharp.setup({

  cmd = { "OmniSharp" }, -- binario de Nix (mayúscula)

  capabilities = capabilities,


  root_dir = lspconfig.util.root_pattern(

    "*.sln",

    "*.csproj",

    ".git"

  ),


  enable_roslyn_analyzers = true,

  enable_import_completion = true,

  organize_imports_on_format = true,

})


-- 2. Configurar Java (jdtls)

-- lspconfig buscará 'jdtls' en el PATH (provisto por Nix)

lspconfig.jdtls.setup({

  capabilities = capabilities,

}) 
