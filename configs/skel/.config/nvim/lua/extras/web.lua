local stacks = require("extras")

vim.list_extend(stacks.treesitter_parsers, {
	"html",
	"javascript",
	"typescript",
	"tsx",
	"json",
	"css",
	"jsdoc",
})
vim.list_extend(stacks.mason_tools, {
	"html-lsp",
	"typescript-language-server",
	"eslint-lsp",
	"css-lsp",
	"json-lsp",
	"prettier",
})

local prettier = { "prettier" }
for _, ft in ipairs({
	"javascript",
	"javascriptreact",
	"typescript",
	"typescriptreact",
	"json",
	"jsonc",
	"css",
	"html",
}) do
	stacks.conform_formatters_by_ft[ft] = prettier
end
