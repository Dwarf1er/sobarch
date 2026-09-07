-- Pinned to "master": upstream's default branch is "main", a rewrite that
-- dropped the "nvim-treesitter.configs" API this file and the extras
-- accumulating into it (see extras/init.lua) rely on.
vim.pack.add({
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "master" },
}, { confirm = false })

vim.api.nvim_create_autocmd("PackChanged", {
	desc = "Handle nvim-treesitter updates",
	group = vim.api.nvim_create_augroup("nvim-treesitter-pack-changed-update-handler", { clear = true }),
	callback = function(event)
		if event.data.kind == "update" then
			vim.notify("nvim-treesitter updated, running TSUpdate...", vim.log.levels.INFO)
			---@diagnostic disable-next-line: param-type-mismatch
			local ok = pcall(vim.cmd, "TSUpdate")
			if ok then
				vim.notify("TSUpdate completed successfully!", vim.log.levels.INFO)
			else
				vim.notify("TSUpdate command not available yet, skipping", vim.log.levels.WARN)
			end
		end
	end,
})

vim.treesitter.query.set("markdown", "injections", "")
