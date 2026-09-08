vim.pack.add({ "https://github.com/stevearc/conform.nvim" }, { confirm = false })

local conform = require("conform")

vim.keymap.set({ "n", "v" }, "<leader>mp", function()
	conform.format({
		lsp_fallback = true,
		async = false,
		timeout_ms = 1000,
	})
end)
