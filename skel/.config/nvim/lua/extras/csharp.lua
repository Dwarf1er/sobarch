vim.filetype.add({
	extension = {
		razor = "razor",
		cshtml = "razor",
	},
})

vim.pack.add({ "https://github.com/seblyng/roslyn.nvim.git" }, { confirm = false })

require("roslyn").setup({
	filetypes = { "cs", "razor" },
	settings = {
		["csharp|inlay_hints"] = {
			csharp_enable_inlay_hints_for_implicit_object_creation = true,
			csharp_enable_inlay_hints_for_implicit_variable_types = true,
			csharp_enable_inlay_hints_for_lambda_parameter_types = true,
			csharp_enable_inlay_hints_for_types = true,
			csharp_enable_inlay_hints_for_indexer_parameters = true,
			csharp_enable_inlay_hints_for_literal_parameters = true,
			csharp_enable_inlay_hints_for_object_creation_parameters = true,
			csharp_enable_inlay_hints_for_other_parameters = true,
			csharp_enable_inlay_hints_for_parameters = true,
			csharp_enable_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
			csharp_enable_inlay_hints_for_parameters_that_match_argument_name = true,
			csharp_enable_inlay_hints_for_parameters_that_match_method_intent = true,
		},
		["csharp|code_lens"] = {
			dotnet_enable_references_code_lens = true,
		},
		["csharp|completion"] = {
			dotnet_show_name_completion_suggestions = true,
			dotnet_show_completion_items_from_unimported_namespaces = true,
		},
		["csharp|background_analysis"] = {
			dotnet_analyzer_diagnostics_scope = "fullSolution",
			dotnet_compiler_diagnostics_scope = "fullSolution",
		},
	},
})

vim.pack.add({ "https://github.com/NicholasMata/nvim-dap-cs" }, { confirm = false })
require("dap-cs").setup()

local stacks = require("extras")
-- Ignoring virtual csharp files for rzls.nvim
table.insert(stacks.telescope_ignore_patterns, "__virtual%.cs$")
vim.list_extend(stacks.treesitter_parsers, { "c_sharp", "razor" })
vim.list_extend(stacks.mason_tools, { "roslyn", "netcoredbg", "csharpier" })
stacks.conform_formatters_by_ft.cs = { "csharpier" }
stacks.conform_formatters.csharpier = {
	command = vim.fn.expand("$MASON/bin") .. "/csharpier",
	args = { "format", "--write-stdout" },
	to_stdin = true,
}
