return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml", ".git" },
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,
			check = {
				command = "clippy",
			},
			cargo = {
				allFeatures = true,
			},
			lens = {
				enable = true,
			},
			assist = {
				importGranularity = "module",
				importPrefix = "by_self",
			},
		},
	},
}
