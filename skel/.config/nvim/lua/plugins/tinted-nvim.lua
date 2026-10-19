vim.pack.add({ "https://github.com/tinted-theming/tinted-nvim" }, { confirm = false })

-- lualine's base16 theme reads the g:tinted_gui0X globals. Registered before
-- setup() so it catches the first load too.
vim.api.nvim_create_autocmd("ColorScheme", {
	desc = "Expose tinted-nvim's palette via the tinted-vim/base16-vim global convention",
	group = vim.api.nvim_create_augroup("tinted-nvim-vim-globals", { clear = true }),
	callback = function()
		local palette = require("tinted-nvim").get_palette()
		if not palette then
			return
		end
		for _, slot in ipairs({ "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "0A", "0B", "0C", "0D", "0E", "0F" }) do
			vim.g["tinted_gui" .. slot] = palette["base" .. slot]
		end
	end,
})

require("tinted-nvim").setup({
	default_scheme = "base16-onedark",
	selector = {
		enabled = true,
		mode = "file",
		path = "~/.local/share/tinted-theming/tinty/current_scheme",
		watch = true,
	},
})
