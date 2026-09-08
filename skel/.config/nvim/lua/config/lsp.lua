vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local opts = { buffer = ev.buf }
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)

		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method("textDocument/inlayHint") then
			vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "gdscript",
	callback = function()
		vim.lsp.start({
			name = "godot",
			cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
			root_dir = vim.fs.root(0, { "project.godot" }),
		})
	end,
})

-- Diagnostics
vim.diagnostic.config({
	virtual_lines = {
		current_line = true,
	},
})
