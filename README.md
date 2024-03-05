# three.nvim

> buffers, windows, and tabs

This plugin is very specific to my workflows. I split it out of my dotfiles to organize it better and get a nice CI setup. You are welcome to use it or draw inspiration from it, but it is expected to not be for everyone. Bug reports may be acted upon, but feature requests will most likely be ignored. There are no guarantees of backwards compatibility.

<!-- TOC -->

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Setup options](#setup-options)
- [three.bufferline](#threebufferline)
  - [save_state()](#save_state)
  - [restore_state(state)](#restore_statestate)
  - [is_buffer_in_any_tab(bufnr)](#is_buffer_in_any_tabbufnr)
  - [get_relative_buffer(bufnr, opts)](#get_relative_bufferbufnr-opts)
  - [next(opts)](#nextopts)
  - [prev(opts)](#prevopts)
  - [move_buffer(position)](#move_bufferposition)
  - [move_buffer_relative(opts)](#move_buffer_relativeopts)
  - [move_right(opts)](#move_rightopts)
  - [move_left(opts)](#move_leftopts)
  - [next_tab(opts)](#next_tabopts)
  - [prev_tab(opts)](#prev_tabopts)
  - [jump_to(idx)](#jump_toidx)
  - [close_buffer(bufnr, force)](#close_bufferbufnr-force)
  - [toggle_pin()](#toggle_pin)
  - [set_pinned(bufnrs, pinned)](#set_pinnedbufnrs-pinned)
  - [clone_tab()](#clone_tab)
  - [smart_close()](#smart_close)
  - [hide_buffer(bufnr)](#hide_bufferbufnr)
  - [get_tab_state(tabpage)](#get_tab_statetabpage)
- [three.windows](#threewindows)
  - [toggle_win_resize()](#toggle_win_resize)
  - [set_win_resize(new_enabled)](#set_win_resizenew_enabled)
- [three.projects](#threeprojects)
  - [add_project(project)](#add_projectproject)
  - [remove_project(project)](#remove_projectproject)
  - [select_project(opts, callback)](#select_projectopts-callback)
  - [open_project(project)](#open_projectproject)
  - [list_projects()](#list_projects)

<!-- /TOC -->

## Requirements

- Neovim 0.7+

## Installation

three.nvim supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'stevearc/three.nvim',
  opts = {},
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require("packer").startup(function()
  use({
    "stevearc/three.nvim",
    config = function()
      require("three").setup()
    end,
  })
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require("paq")({
  { "stevearc/three.nvim" },
})
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'stevearc/three.nvim'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('stevearc/three.nvim')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/stevearc/three.nvim.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/three.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/three/start/three.nvim
```

</details>

## Quick start

Add the following to your init.lua

```lua
require("three").setup()
```

Optionally, set up some keymaps. Here are some recommended ones to start with

```lua
local three = require('three')
-- Keymaps for bufferline
vim.keymap.set("n", "<C-l>", three.next, { desc = "Next buffer" })
vim.keymap.set("n", "<C-h>", three.prev, { desc = "Previous buffer" })
vim.keymap.set("n", "gt", three.wrap(three.next_tab, { wrap = true }, { desc = "[G]oto next [T]ab" }))
vim.keymap.set("n", "gT", three.wrap(three.prev_tab, { wrap = true }, { desc = "[G]oto prev [T]ab" }))
for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, three.wrap(three.jump_to, i), desc = {"Jump to buffer " .. three.jump_to)
end
vim.keymap.set("n", "<leader>0", three.wrap(three.jump_to, 10), { desc = "Jump to buffer 10" })
vim.keymap.set("n", "<leader>`", three.wrap(three.next, { delta = 100 }), { desc = "Jump to last buffer" })
vim.keymap.set("n", "<leader>c", three.smart_close, { desc = "[C]lose window or buffer" })
vim.keymap.set("n", "<leader>bc", three.close_buffer, { desc = "[B]uffer [C]lose" })
vim.keymap.set("n", "<leader>bh", three.hide_buffer, { desc = "[B]uffer [H]ide" })
vim.keymap.set("n", "<leader>bp", three.toggle_pin, { desc = "[B]uffer [P]in" })
vim.keymap.set("n", "<leader>bm", function()
  vim.ui.input({ prompt = "Move buffer to:" }, function(idx)
    idx = idx and tonumber(idx)
    if idx then
      three.move_buffer(idx)
    end
  end)
end, { desc = "[B]uffer [M]ove" })
vim.keymap.set("n", "<C-w><C-t>", "<cmd>tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("n", "<C-w><C-b>", three.clone_tab, { desc = "Clone tab" })
vim.keymap.set("n", "<C-w><C-n>", "<cmd>tabnew | set nobuflisted<CR>", { desc = "New tab" })

-- Keymaps for projects
vim.keymap.set("n", "<leader>fp", three.open_project, { desc = "[F]ind [P]roject" })
vim.api.nvim_create_user_command("ProjectDelete", function()
  three.remove_project()
end, {})
```

## Setup options

```lua
require("three").setup({
  bufferline = {
    enabled = true,
    icon = {
      -- Tab left/right dividers
      -- Set to this value for more a more compact look
      -- dividers = { "▍", "" },
      dividers = { " ", "" },
      -- Scroll indicator icons when buffers exceed screen width
      scroll = { "«", "»" },
      -- Divider between pinned buffers and others
      pin_divider = "",
      -- Pinned buffer icon
      pin = "󰐃",
    },
    -- List of autocmd events that will trigger a re-render of the bufferline
    events = {},
    should_display = function(tabpage, bufnr, ts)
      return vim.bo[bufnr].buflisted or vim.bo[bufnr].modified
    end,
    -- Number of tabs to use for buffers with should_display = false
    recency_slots = 1,
  },
  windows = {
    enabled = true,
    -- Constant or function to calculate the minimum window width of the focused window
    winwidth = function(winid)
      local bufnr = vim.api.nvim_win_get_buf(winid)
      return math.max(vim.bo[bufnr].textwidth, 80)
    end,
    -- Constant or function to calculate the minimum window height of the focused window
    winheight = 10,
  },
  projects = {
    enabled = true,
    -- Name of file to store the project directory cache
    filename = "projects.json",
    -- When true, automatically add directories entered as projects
    -- If false, you will need to manually call add_project()
    autoadd = true,
    -- List of lua patterns. If any match the directory, it will be allowed as a project
    allowlist = {},
    -- List of lua patterns. If any match the directory, it will be ignored as a project
    blocklist = {},
    -- Return true to allow a directory as a project
    filter_dir = function(dir)
      return true
    end,
  },
})
```

## three.bufferline

A bufferline that replaces the tabline. It is designed for the workflow of having one tab open per-project directory.

<!-- bufferline API -->

### save_state()

`save_state(): any` \
Get the saved state of the bufferline


### restore_state(state)

`restore_state(state)` \
Restore the previously saved state

| Param | Type  | Desc |
| ----- | ----- | ---- |
| state | `any` |      |

### is_buffer_in_any_tab(bufnr)

`is_buffer_in_any_tab(bufnr): boolean` \
Check if buffer is listed in any tab

| Param | Type      | Desc |
| ----- | --------- | ---- |
| bufnr | `integer` |      |

### get_relative_buffer(bufnr, opts)

`get_relative_buffer(bufnr, opts): nil|integer`

| Param | Type      | Desc           |     |
| ----- | --------- | -------------- | --- |
| bufnr | `integer` |                |     |
| opts  | `table`   |                |     |
|       | delta     | `nil\|integer` |     |
|       | wrap      | `nil\|boolean` |     |

### next(opts)

`next(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### prev(opts)

`prev(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### move_buffer(position)

`move_buffer(position)`

| Param    | Type      | Desc |
| -------- | --------- | ---- |
| position | `integer` |      |

### move_buffer_relative(opts)

`move_buffer_relative(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### move_right(opts)

`move_right(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### move_left(opts)

`move_left(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### next_tab(opts)

`next_tab(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### prev_tab(opts)

`prev_tab(opts)`

| Param | Type    | Desc           |     |
| ----- | ------- | -------------- | --- |
| opts  | `table` |                |     |
|       | delta   | `nil\|integer` |     |
|       | wrap    | `nil\|boolean` |     |

### jump_to(idx)

`jump_to(idx)`

| Param | Type      | Desc |
| ----- | --------- | ---- |
| idx   | `integer` |      |

### close_buffer(bufnr, force)

`close_buffer(bufnr, force)`

| Param | Type           | Desc |
| ----- | -------------- | ---- |
| bufnr | `nil\|integer` |      |
| force | `nil\|boolean` |      |

### toggle_pin()

`toggle_pin()` \
Toggle the pinned status of the current buffer


### set_pinned(bufnrs, pinned)

`set_pinned(bufnrs, pinned)` \
Set the pinned status of a buffer or buffers

| Param  | Type                 | Desc |
| ------ | -------------------- | ---- |
| bufnrs | `integer\|integer[]` |      |
| pinned | `boolean`            |      |

### clone_tab()

`clone_tab()` \
Clone the current tab into a new tab


### smart_close()

`smart_close()` \
Close the current window or buffer


### hide_buffer(bufnr)

`hide_buffer(bufnr)` \
Hide the buffer from the current tab

| Param | Type           | Desc |
| ----- | -------------- | ---- |
| bufnr | `nil\|integer` |      |

### get_tab_state(tabpage)

`get_tab_state(tabpage): three.TabState`

| Param   | Type      | Desc |
| ------- | --------- | ---- |
| tabpage | `integer` |      |


<!-- /bufferline API -->

## three.windows

The windows module does two things: it tries to keep all windows equally sized, and it provides a replacement for `winheight` and `winwidth` that ignores windows with `winfixheight` and `winfixwidth`.

<!-- windows API -->

### toggle_win_resize()

`toggle_win_resize(): boolean`


### set_win_resize(new_enabled)

`set_win_resize(new_enabled)`

| Param       | Type      | Desc |
| ----------- | --------- | ---- |
| new_enabled | `boolean` |      |


<!-- /windows API -->

## three.projects

The projects module allows you to bookmark project directories and quickly open them in a new tab.

<!-- projects API -->

### add_project(project)

`add_project(project)`

| Param   | Type     | Desc |
| ------- | -------- | ---- |
| project | `string` |      |

### remove_project(project)

`remove_project(project)`

| Param   | Type          | Desc |
| ------- | ------------- | ---- |
| project | `nil\|string` |      |

### select_project(opts, callback)

`select_project(opts, callback)`

| Param    | Type                        | Desc                    |
| -------- | --------------------------- | ----------------------- |
| opts     | `table`                     | See :help vim.ui.select |
| callback | `fun(project: nil\|string)` |                         |

### open_project(project)

`open_project(project)`

| Param   | Type          | Desc |
| ------- | ------------- | ---- |
| project | `nil\|string` |      |

### list_projects()

`list_projects(): string[]`



<!-- /projects API -->
