-- Core
require("config.globals")
require("config.options")
require("config.keymap")
require("config.autocmd")
require("config.commands")

-- Plugins
require("plugins.mason-nvim")
require("plugins.nvim-treesitter")
-- Must load before lualine so its ColorScheme autocmd runs first.
require("plugins.tinted-nvim")
require("plugins.lualine-nvim")
require("plugins.telescope-nvim")
require("plugins.nvim-dap")
require("plugins.conform-nvim")
require("plugins.nvim-cmp")
require("plugins.autoclose-nvim")
require("plugins.markdown-toc-nvim")

-- LSP configuration
require("config.lsp")

-- Enable per-language extras (Rust, Go, C#, ...) by requiring them from lua/local.lua.
pcall(dofile, os.getenv("HOME") .. "/.config/nvim/lua/local.lua")

-- Must run after all extras are loaded.
require("extras").finalize()
