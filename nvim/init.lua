-- Minimal, single-file Neovim config. Plugins are managed by lazy.nvim and
-- installed automatically on first start (needs git + network).

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Options ---------------------------------------------------------------------
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.inccommand = "split"
opt.termguicolors = true
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.breakindent = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Share the system clipboard locally. Over ssh, yank with "+y instead: it is
-- copied through OSC 52, which avoids slow clipboard reads on every paste.
if not vim.env.SSH_TTY then
  vim.schedule(function() opt.clipboard = "unnamedplus" end)
end

-- Keymaps ---------------------------------------------------------------------
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("v", "<", "<gv")
map("v", ">", ">gv")
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Prev diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  callback = function() vim.hl.on_yank() end,
})

-- Plugins ---------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  if vim.fn.executable("git") == 0 then
    vim.notify("git not found: skipping plugins", vim.log.levels.WARN)
    vim.cmd.colorscheme("habamax")
    return
  end
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
end
opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function() vim.cmd.colorscheme("tokyonight-night") end,
  },
  {
    -- Fuzzy finding powered by the fzf binary installed by install.sh.
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    opts = { defaults = { file_icons = false } },
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Grep" },
      { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Buffers" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
      { "<leader>fh", "<cmd>FzfLua helptags<CR>", desc = "Help" },
      { "<leader>fk", "<cmd>FzfLua keymaps<CR>", desc = "Keymaps" },
      { "<leader>/", "<cmd>FzfLua grep_curbuf<CR>", desc = "Search buffer" },
      { "<leader><leader>", "<cmd>FzfLua resume<CR>", desc = "Resume last search" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },
  {
    -- Shows available keybindings as you type (try pressing <space>).
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = { icons = { mappings = false } },
  },
}, {
  -- Plain icons: servers usually aren't viewed through a Nerd Font.
  ui = {
    icons = {
      cmd = "⌘", config = "🛠", event = "📅", ft = "📂", init = "⚙",
      keys = "🗝", plugin = "🔌", runtime = "💻", require = "🌙",
      source = "📄", start = "🚀", task = "📌", lazy = "💤 ",
    },
  },
  checker = { enabled = false },
  change_detection = { notify = false },
})
