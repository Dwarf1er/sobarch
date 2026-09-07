vim.pack.add({ "https://github.com/nvim-lua/plenary.nvim.git" }, { confirm = false })

vim.api.nvim_create_autocmd("PackChanged", {
	desc = "Build telescope-fzf-native.nvim's native library on install",
	group = vim.api.nvim_create_augroup("telescope-fzf-native-build", { clear = true }),
	callback = function(event)
		if event.data.spec.name ~= "telescope-fzf-native.nvim" or event.data.kind ~= "install" then
			return
		end
		if vim.fn.executable("make") == 1 then
			vim.system({ "make" }, { cwd = event.data.path }):wait()
		else
			vim.notify("telescope-fzf-native.nvim: 'make' not found, native extension not built", vim.log.levels.WARN)
		end
	end,
})

vim.pack.add({ "https://github.com/nvim-telescope/telescope-fzf-native.nvim.git" }, { confirm = false })
vim.pack.add({ "https://github.com/nvim-telescope/telescope.nvim.git" }, { confirm = false })

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })
