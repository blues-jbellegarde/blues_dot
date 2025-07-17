return {
	"benlubas/molten-nvim",
	version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
	dependencies = { "3rd/image.nvim", lazy = true },
	build = ":UpdateRemotePlugins",
	lazy = true,
	init = function()
		-- these are examples, not defaults. Please see the readme
		vim.g.molten_image_provider = "image.nvim"
		vim.g.molten_output_win_max_height = 20
		vim.keymap.set("n", "<localleader>mi", ":MoltenInit<CR>", { silent = true, desc = "Initialize the plugin" })
		vim.keymap.set(
			"n",
			"<localleader>mr",
			":MoltenEvaluateOperator<CR>",
			{ silent = true, desc = "run operator selection" }
		)
		vim.keymap.set("n", "<localleader>ml", ":MoltenEvaluateLine<CR>", { silent = true, desc = "evaluate line" })
		vim.keymap.set(
			"n",
			"<localleader>mc",
			":MoltenReevaluateCell<CR>",
			{ silent = true, desc = "re-evaluate cell" }
		)
		vim.keymap.set(
			"v",
			"<localleader>ms",
			":<C-u>MoltenEvaluateVisual<CR>gv",
			{ silent = true, desc = "evaluate visual selection" }
		)
		vim.keymap.set("n", "<localleader>md", ":MoltenDelete<CR>", { silent = true, desc = "molten delete cell" })
		vim.keymap.set("n", "<localleader>mh", ":MoltenHideOutput<CR>", { silent = true, desc = "hide output" })
		vim.keymap.set(
			"n",
			"<localleader>mo",
			":noautocmd MoltenEnterOutput<CR>",
			{ silent = true, desc = "show/enter output" }
		)
	end,
}
