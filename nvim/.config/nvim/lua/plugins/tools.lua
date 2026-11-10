-- Debugger (Python). Loads only when one of the <Space>d keys is pressed.
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint on this line" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Start / continue" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to the cursor" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Stop" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debugger windows" },
      { "<leader>de", function() require("dapui").eval() end, mode = { "n", "x" }, desc = "Evaluate under cursor / selection" },
    },
    config = function()
      local dap, ui = require("dap"), require("dapui")
      ui.setup()
      dap.listeners.after.event_initialized.rice = function() ui.open() end
      dap.listeners.before.event_terminated.rice = function() ui.close() end
      dap.listeners.before.event_exited.rice = function() ui.close() end
      -- made by install.sh: uv venv ~/.local/share/nvim/debugpy && uv pip install debugpy
      local debugpy = vim.fn.stdpath("data") .. "/debugpy/bin/python"
      require("dap-python").setup(vim.uv.fs_stat(debugpy) and debugpy or "python3")
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "CursorLine" })
    end,
  },
}
