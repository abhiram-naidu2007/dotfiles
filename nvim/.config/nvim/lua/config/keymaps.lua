-- Keys that do not belong to a plugin. Plugin keys sit next to the plugin (lua/plugins).
-- <Space> is the leader; wait a moment after pressing it and a popup lists what comes next.
local map = vim.keymap.set

-- stay oriented
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, centred" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, centred" })
map("n", "n", "nzzzv", { desc = "Next match, centred" })
map("n", "N", "Nzzzv", { desc = "Previous match, centred" })
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (by screen line when wrapped)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (by screen line when wrapped)" })

-- files and buffers
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Write file" })
map({ "n", "x" }, "<C-s>", "<cmd>write<cr>", { desc = "Write file" })
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<C-i>", "<C-i>", { desc = "Jump forward (kept apart from Tab)" })
map("n", "<leader>qq", "<cmd>quitall<cr>", { desc = "Quit Neovim" })

-- windows: <Space>s = split
map("n", "<leader>sv", "<C-w>v", { desc = "Split right" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split below" })
map("n", "<leader>se", "<C-w>=", { desc = "Equal sizes" })
map("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close this split" })
map("n", "<leader>so", "<C-w>o", { desc = "Only this split" })
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window below" })
map("n", "<C-k>", "<C-w>k", { desc = "Window above" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Taller" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Shorter" })
map("n", "<C-Left>", "<cmd>vertical resize -4<cr>", { desc = "Narrower" })
map("n", "<C-Right>", "<cmd>vertical resize +4<cr>", { desc = "Wider" })

-- editing
map("x", "J", ":m '>+1<cr>gv=gv", { silent = true, desc = "Move selection down" })
map("x", "K", ":m '<-2<cr>gv=gv", { silent = true, desc = "Move selection up" })
map("x", "<", "<gv", { desc = "Dedent, keep selection" })
map("x", ">", ">gv", { desc = "Indent, keep selection" })
map("x", "p", '"_dP', { desc = "Paste over selection, keep what was yanked" })
map("n", "<leader>cs", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Substitute the word under the cursor" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Explain the problem on this line" })

-- lists
map("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix list" })
map("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Location list" })

-- terminal
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })

-- own tools (lua/rice)
map("n", "<leader>r", function() require("rice.run").file() end, { desc = "Run this file" })
map("n", "<leader>fe", function() require("rice.evry").pick() end, { desc = "Everything: any file on the disk" })
map("n", "<leader>tt", function() require("rice.tricks").show() end, { desc = "A trick to practise" })
map("n", "<leader>tl", function() require("rice.tricks").pick() end, { desc = "All tricks" })
map("n", "<leader>tk", "<cmd>edit ~/dotfiles/docs/nvim.md<cr>", { desc = "Key map of this config" })

map("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Plugins" })
map("n", "<leader>m", "<cmd>Mason<cr>", { desc = "Language servers and tools" })
