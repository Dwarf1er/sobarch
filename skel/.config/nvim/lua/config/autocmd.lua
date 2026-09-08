vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	desc = "Use 2-space indentation for web filetypes",
	group = vim.api.nvim_create_augroup("web-indent", { clear = true }),
	pattern = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"json",
		"jsonc",
		"css",
		"html",
	},
	callback = function()
		vim.bo.shiftwidth = 2
		vim.bo.softtabstop = 2
		vim.bo.tabstop = 2
	end,
})
