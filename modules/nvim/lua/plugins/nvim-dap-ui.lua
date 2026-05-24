local dap, dapui = require("dap"),require("dapui")

-- Setup DAPUI
dapui.setup({
  icons = { collapsed = "", current_frame = "", expanded = "" },
  layouts = {
    {
      elements = { "scopes", "watches", "stacks", "breakpoints" },
      size = 80,
      position = "left",
    },
    { elements = { "console", "repl" }, size = 0.25, position = "bottom" },
  },
  render = { indent = 2 },
})

