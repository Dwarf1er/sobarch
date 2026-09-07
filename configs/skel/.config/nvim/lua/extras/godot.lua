local stacks = require("extras")

table.insert(stacks.mason_registries, "github:Crashdummyy/mason-registry")
vim.list_extend(stacks.mason_tools, { "gdtoolkit", "gdscript-formatter" })
vim.list_extend(stacks.treesitter_parsers, { "gdscript", "godot_resource", "gdshader", "c", "cpp" })

-- godot editor setting: --server {project}/server.pipe --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line}+1,{col})<CR>"
local project_root = vim.fs.root(vim.fn.getcwd(), "project.godot")
if project_root then
	local pipe = project_root .. "/server.pipe"
	if not vim.uv.fs_stat(pipe) then
		vim.fn.serverstart(pipe)
	end
end

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

local dap = require("dap")
dap.adapters.godot = {
	type = "server",
	host = "127.0.0.1",
	port = 6007,
}
dap.configurations.gdscript = {
	{
		name = "Launch scene",
		type = "godot",
		request = "launch",
		project = "${workspaceFolder}",
		launch_game_instance = false,
		launch_scene = false,
	},
}
