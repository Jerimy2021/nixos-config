local dap, dapui, hydra = require("dap"), require("dapui"), require("hydra")

-- Set Icons

vim.api.nvim_call_function(
 "sign_define",
 { "DapBreakpoint", { linehl = "", text = "", texthl = "diffRemoved", numhl = "" } }
)

vim.api.nvim_call_function(
 "sign_define",
 { "DapBreakpointCondition", { linehl = "", text = "", texthl = "diffRemoved", numhl = "" } }
)

vim.api.nvim_call_function(
 "sign_define",
 { "DapLogPoint", { linehl = "", text = "", texthl = "diffRemoved", numhl = "" } }
)

vim.api.nvim_call_function(
 "sign_define",
 { "DapStopped", { linehl = "GitSignsChangeVirtLn", text = "", texthl = "diffChanged", numhl = "" } }
)

vim.api.nvim_call_function(
 "sign_define",
 { "DapBreakpointRejected", { linehl = "", text = "", texthl = "", numhl = "" } }
)

-- Added event for open DAUI
dap.listeners.after.event_initialized['dapui_config'] = function()
	dapui.open()
end

dap.adapters.python = function(cb, config)
  if config.request == 'attach' then
    ---@diagnostic disable-next-line: undefined-field
    local port = (config.connect or config).port
    ---@diagnostic disable-next-line: undefined-field
    local host = (config.connect or config).host or '127.0.0.1'
    cb({
      type = 'server',
      port = assert(port, '`connect.port` is required for a python `attach` configuration'),
      host = host,
      options = {
        source_filetype = 'python',
      },
    })
  else
    cb({
      type = 'executable',
      command = '/Users/pierre/.virtualenvs/debugpy/bin/python3',
      args = { '-m', 'debugpy.adapter' },
      options = {
        source_filetype = 'python',
      },
    })
  end
end

dap.configurations.python = {
  {
    -- The first three options are required by nvim-dap
    type = 'python'; -- the type here established the link to the adapter definition: `dap.adapters.python`
    request = 'launch';
    name = "Launch file";

    -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

    program = "${file}"; -- This configuration will launch the current file if used.
    pythonPath = function()
      -- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
      -- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
      -- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.
      local cwd = vim.fn.getcwd()
      if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
        return cwd .. '/venv/bin/python'
      elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
        return cwd .. '/.venv/bin/python'
      else
        return '/usr/bin/python3'
      end
    end;
  },
}


dap.adapters.codelldb = {
  type = "server",
  host = "127.0.0.1",
  port = "${port}",
  executable = {
	  command = "codelldb",
	  args = {
		  "--port",
		  "${port}"
	  },
  },

}

dap.configurations.cpp = {
  {
    name = "Launch codelldb",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    args = {},
    runInTerminal = true,
  },
}

dap.configurations.c = dap.configurations.cpp

-- 1. El adaptador: Conecta nvim-dap con netcoredbg (provisto por Nix)
dap.adapters.coreclr = {
  type = 'executable',
  command = 'netcoredbg', 
  args = {'--interpreter=vscode'}
}

dap.configurations.cs = {
  {
    type = "coreclr",
    name = "Launch - netcoredbg",
    request = "launch",
    program = function()
        -- Aquí va tu función de selección de DLL (la que te pasé antes)
        -- Asegúrate de elegir: .../Supplier.Web.Host.dll
        return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/Supplier.Web.Host/bin/Debug/net9.0/', 'file')
    end,
    
    -- 👇 CWD DINÁMICO 👇
    cwd = function()
        -- Opción 1: Si tus configs se copian al bin (output), usa esto:
        -- return vim.fn.fnamemodify(dap.configurations.cs[1].program(), ":h")
        
        -- Opción 2 (La que necesitas para log4net/appsettings):
        -- Usar la carpeta del proyecto fuente (src/Supplier.Web.Host)
        return vim.fn.getcwd() .. '/Supplier.Web.Host' 
    end,
    
    env = {
        ASPNETCORE_ENVIRONMENT = "Development"
    }
  },
}
