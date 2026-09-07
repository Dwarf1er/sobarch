local stacks = require("extras")

table.insert(stacks.treesitter_parsers, "go")
vim.list_extend(stacks.mason_tools, { "gopls", "goimports", "gofumpt" })
stacks.conform_formatters_by_ft.go = { "goimports", "gofumpt" }
