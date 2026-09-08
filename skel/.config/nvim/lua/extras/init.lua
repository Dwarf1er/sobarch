local M = {
	mason_registries = { "github:mason-org/mason-registry" },
	mason_tools = { "lua_ls", "stylua" },
	treesitter_parsers = { "lua", "markdown" },
	conform_formatters_by_ft = { lua = { "stylua" } },
	conform_formatters = {},
	telescope_ignore_patterns = {},
}

function M.finalize()
	require("mason").setup({ registries = M.mason_registries })
	require("mason-lspconfig").setup()
	require("mason-tool-installer").setup({ ensure_installed = M.mason_tools })

	require("nvim-treesitter.configs").setup({
		build = ":TSUpdate",
		ensure_installed = M.treesitter_parsers,
		auto_install = false,
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		},
		indent = {
			enable = true,
		},
	})

	require("conform").setup({
		formatters_by_ft = M.conform_formatters_by_ft,
		formatters = M.conform_formatters,
		format_on_save = {
			lsp_fallback = true,
			async = false,
			timeout_ms = 1000,
		},
	})

	require("telescope").setup({
		defaults = {
			file_ignore_patterns = M.telescope_ignore_patterns,
		},
	})
	pcall(require("telescope").load_extension, "fzf")
end

return M
