-- Core
require("config.globals")
require("config.options")
require("config.keymap")
require("config.autocmd")
require("config.commands")

-- Plugins
require("plugins.mason-nvim")
require("plugins.nvim-treesitter")
-- Registered before lualine: lualine re-runs its own setup() on every
-- ColorScheme event too, so tinted-nvim's globals-sync autocmd (see
-- plugins/tinted-nvim.lua) must be registered first to avoid lualine
-- reading one-scheme-stale globals on every live theme switch.
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

-- Optional per-language extras (Rust, Go, web, C#, Godot, ...), toggled by
-- requiring them from ~/.config/nvim/lua/local.lua. Not tracked by the
-- dotfiles/distro defaults; safe to be absent.
pcall(dofile, os.getenv("HOME") .. "/.config/nvim/lua/local.lua")

-- Tool-installer/treesitter/conform setup, run once core and any extras
-- above have registered everything they need into the shared extras state.
require("extras").finalize()
