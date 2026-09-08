local stacks = require("extras")

table.insert(stacks.treesitter_parsers, "rust")
table.insert(stacks.mason_tools, "rust-analyzer")
stacks.conform_formatters_by_ft.rust = { "rustfmt" }
