local parsers = {
	"vim",
	"vimdoc",
	"lua",
	"query",
	"python",
	"go",
	"javascript",
	"typescript",
	"sql",
	"bash",
	"markdown",
	"markdown_inline",
	"json",
	"yaml",
	"toml",
	"html",
	"css",
	"git_config",
	"git_rebase",
	"gitcommit",
	"gitignore",
	"gitattributes",
	"csv",
	"dockerfile",
	"terraform",
	"diff",
	"just",
	"regex",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup()

		-- Install any missing parsers from the list above
		local installed = require("nvim-treesitter").get_installed()
		local missing = vim.tbl_filter(function(p)
			return not vim.tbl_contains(installed, p)
		end, parsers)
		if #missing > 0 then
			require("nvim-treesitter").install(missing)
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				pcall(vim.treesitter.start)
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
