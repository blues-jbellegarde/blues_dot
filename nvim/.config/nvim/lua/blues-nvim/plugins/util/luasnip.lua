return {
	"L3MON4D3/LuaSnip",
	lazy = false,
	event = { "BufReadPre", "BufNewFile" }, -- to disable, comment this out
	-- follow latest release.
	version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
	-- install jsregexp (optional!).
	build = "make install_jsregexp",
	config = function()
		local ls = require("luasnip")

		-- Setup LuaSnip
		ls.setup({
			history = true,
			updateevents = "TextChanged,TextChangedI",
		})

		-- Define keymaps AFTER setup
		vim.keymap.set({ "i" }, "<leader>le", function()
			ls.expand()
		end, { silent = true, desc = "LuaSnip expand" })

		vim.keymap.set({ "i", "s" }, "<leader>ln", function()
			ls.jump(1)
		end, { silent = true, desc = "LuaSnip jump next" })

		vim.keymap.set({ "i", "s" }, "<leader>lp", function()
			ls.jump(-1)
		end, { silent = true, desc = "LuaSnip jump previous" })

		vim.keymap.set({ "i", "s" }, "<leader>lm", function()
			if ls.choice_active() then
				ls.change_choice(1)
			end
		end, { silent = true, desc = "LuaSnip change choice" })
	end,
}
