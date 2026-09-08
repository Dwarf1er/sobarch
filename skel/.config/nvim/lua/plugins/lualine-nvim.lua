vim.pack.add({ "https://github.com/nvim-lualine/lualine.nvim" }, { confirm = false })
require("lualine").setup({
	options = {
		icons_enabled = false,
		theme = "auto",
		component_separators = "|",
		section_separators = "",
	},
})
