+++
title = "Neovim"
description = "A from-scratch Lua config using Neovim's own built-in plugin manager, with optional per-language extras."
weight = 20
template = "docs/page.html"

[extra]
lead = "Neovim ships by default, not as a profile pick, with a plain Lua config built on Neovim's own vim.pack plugin manager rather than a third-party one."
toc = true
+++

The config isn't a distribution like LazyVim: it's a small, from-scratch
set of Lua files using Neovim's own built-in `vim.pack` plugin manager,
so there's no separate plugin-manager runtime to learn or update.

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/shell-editor/neovim.webp" width="1351" height="685" alt="Neovim with LSP, treesitter, and the tinty-themed colorscheme">
</figure>

## What's included

- **[mason.nvim](https://github.com/mason-org/mason.nvim)** installs
  and manages LSP servers, formatters, and debug adapters on demand.
- **nvim-treesitter**, **nvim-cmp** (completion), **nvim-dap**
  (debugging), and **conform.nvim** (formatting, on save) handle the
  rest of the core editing experience.
- **telescope.nvim** (with `fzf-native`) for fuzzy finding, **lualine.nvim**
  for the statusline, **autoclose.nvim** and **markdown-toc.nvim** for
  smaller conveniences.
- **tinted-nvim** keeps the editor's colors in sync with the desktop's
  active [theme](../../desktop/theming/), the same as every other
  themed app.

LSP servers for `lua_ls`, `rust_analyzer`, `ts_ls`, and `gdscript` are
configured out of the box via Neovim's native `vim.lsp.config`
mechanism; hover (`K`), go to definition (`<leader>gd`), references
(`<leader>gr`), and code actions (`<leader>ca`) all work as soon as one
attaches.

## Optional language extras

Rust, Go, Web (JS/TS/CSS/HTML/JSON), C# (via Roslyn, with debugging),
and Godot each have a ready-made extra that adds its own treesitter
parsers, Mason-installed LSP servers and formatters, and (for C# and
Godot) debug adapters. None of them load by default: create
`~/.config/nvim/lua/local.lua` and require the ones you want, for
example:

```lua
require("extras.rust")
require("extras.web")
```

`local.lua` isn't tracked by sobarch's dotfiles or touched by
[Updating Your Config](../../desktop/updating-config/), so it's safe
to leave absent or customize freely.
