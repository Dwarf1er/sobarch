vim.pack.add({ "https://github.com/tinted-theming/tinted-nvim" }, { confirm = false })

require("tinted-nvim").setup({
	default_scheme = "base16-onedark",
	selector = {
		enabled = true,
		mode = "file",
		path = "~/.local/share/tinted-theming/tinty/current_scheme",
		watch = true,
	},
})
