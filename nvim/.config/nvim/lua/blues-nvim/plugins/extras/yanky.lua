-- better yank/paste
return {
	"gbprod/yanky.nvim",
	lazy = true,
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	recommended = true,
	desc = "Better Yank/Paste",
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		keymaps = {
			vim.keymap.set(
				{ "n", "x" },
				"<leader>yh",
				"<cmd>Telescope yank_history<cr>",
				{ desc = "Open yanky history" }
			),
			vim.keymap.set({ "n", "x" }, "<leader>yy", "<Plug>(YankyYank)", { desc = "Yank Text" }),
			vim.keymap.set({ "n", "x" }, "<leader>yp", "<Plug>(YankyPutAfter)", { desc = "Put Text After Cursor" }),
			vim.keymap.set({ "n", "x" }, "<leader>yP", "<Plug>(YankyPutBefore)", { desc = "Put Text Before Cursor" }),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>ygp",
				"<Plug>(YankyGPutAfter)",
				{ desc = "Put Text After Selection" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>ygP",
				"<Plug>(YankyGPutBefore)",
				{ desc = "Put Text Before Selection" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y[[",
				"<Plug>(YankyCycleForward)",
				{ desc = "Cycle Forward Through Yank History" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y]]",
				"<Plug>(YankyCycleBackward)",
				{ desc = "Cycle Backward Through Yank History" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y]p",
				"<Plug>(YankyPutIndentAfterLinewise)",
				{ desc = "Put Indented After Cursor (Linewise)" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y[p",
				"<Plug>(YankyPutIndentBeforeLinewise)",
				{ desc = "Put Indented Before Cursor (Linewise)" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y]P",
				"<Plug>(YankyPutIndentAfterLinewise)",
				{ desc = "Put Indented After Cursor (Linewise)" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y[P",
				"<Plug>(YankyPutIndentBeforeLinewise)",
				{ desc = "Put Indented Before Cursor (Linewise)" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y>p",
				"<Plug>(YankyPutIndentAfterShiftRight)",
				{ desc = "Put and Indent Right" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y<p",
				"<Plug>(YankyPutIndentAfterShiftLeft)",
				{ desc = "Put and Indent Left" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y>P",
				"<Plug>(YankyPutIndentBeforeShiftRight)",
				{ desc = "Put Before and Indent Right" }
			),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y<P",
				"<Plug>(YankyPutIndentBeforeShiftLeft)",
				{ desc = "Put Before and Indent Left" }
			),
			vim.keymap.set({ "n", "x" }, "=p", "<Plug>(YankyPutAfterFilter)", { desc = "Put After Applying a Filter" }),
			vim.keymap.set(
				{ "n", "x" },
				"<leader>y=P",
				"<Plug>(YankyPutBeforeFilter)",
				{ desc = "Put Before Applying a Filter" }
			),
		},
	},
}
