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

-- tinted-nvim only bundles upstream schemes, so tinty's extra and custom ones
-- are passed in.
local function custom_schemes()
	local schemes = {}
	local data = vim.fn.expand("~/.local/share/tinted-theming/tinty")
	local roots = vim.tbl_filter(function(dir)
		return vim.fn.fnamemodify(dir, ":t") ~= "schemes"
	end, vim.fn.glob(data .. "/scheme-repos/*", false, true))
	table.insert(roots, data .. "/custom-schemes")
	for _, root in ipairs(roots) do
		for _, system in ipairs({ "base16", "base24" }) do
			for _, file in ipairs(vim.fn.glob(root .. "/" .. system .. "/*.y*ml", false, true)) do
				local scheme = { variant = "dark" }
				for line in io.lines(file) do
					local slot, hex = line:match("^%s*base(%x%x)%s*:%s*[\"']?#?(%x%x%x%x%x%x)")
					if slot then
						scheme["base" .. slot:upper()] = "#" .. hex:lower()
					end
					local variant = line:match("^%s*variant%s*:%s*[\"']?(%a+)")
					if variant == "dark" or variant == "light" then
						scheme.variant = variant
					end
				end
				schemes[system .. "-" .. vim.fn.fnamemodify(file, ":t:r")] = scheme
			end
		end
	end
	return schemes
end

require("tinted-nvim").setup({
	default_scheme = "base16-onedark",
	schemes = custom_schemes(),
	selector = {
		enabled = true,
		mode = "file",
		path = "~/.local/share/tinted-theming/tinty/current_scheme",
		watch = true,
	},
})
