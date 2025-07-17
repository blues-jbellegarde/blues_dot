-- https://github.com/nvim-neorg/neorg/wiki/Default-Keybinds
return {
	"nvim-neorg/neorg",
	lazy = false,
	ft = { "norg" },
	version = "*",
	config = function()
		local wo = vim.wo
		local keymap = vim.keymap

		require("neorg").setup({
			load = {
				["core.defaults"] = {},
				["core.completion"] = {
					config = {
						engine = "nvim-cmp",
					},
				},
				["core.export.markdown"] = {},
				["core.presenter"] = {
					config = {
						zen_mode = "zen-mode",
					},
				},
				["core.summary"] = {},
				["core.concealer"] = {},
				["core.dirman"] = {
					config = {
						workspaces = {
							notes = "~/notes",
						},
						default_workspace = "notes",
					},
				},
			},
		})
		wo.foldlevel = 99
		wo.conceallevel = 2
		keymap.set("n", "<localleader>nt", "<Plug>(neorg.dirman.new-note)", { desc = "Create New Today Entry" })
	end,
}
