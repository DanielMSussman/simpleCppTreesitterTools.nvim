# simpleCppTreesitterTools.nvim 

This plugin used to just be a messy lua file in my `/after/ftplugin/` directory. 
When I asked on reddit for [suggestions for cpp plugins](https://www.reddit.com/r/neovim/comments/1h53req/neovim_and_c_luasnip_treesitter_and_reinventing/), it was suggested that
there weren't as many such plugins, or even resources for learning about treesitter's
query system, as I might have expected.

Hence: a plugin which might be slightly useful when coding, and which might be helpful
to learn a bit about using treesitter.

## Features

This plugin does four major things. The main function is `ImplementMembersInClass`... 
A specialized version, `ImplementMemberOnCursorLine`, only tries to do this for whatever line your cursor happens to be on.
A third command, `CreateDerivedClass` takes the current class and creates a new header file, which contains a class that inherits from the current class. Virtual functions (or, optionally, only pure virtual functions) in the current class are added as members of the derived class.

Finally, probably most importantly, I've tried to write things so that it's easy to understand the structure of how I'm using and parsing treesitter queries.


## Installation

### lazy.nvim
```lua
{
"DanielMSussman/simpleCppTreesitterTools.nvim",
dependencies = { 'nvim-treesitter/nvim-treesitter'},

config = function()
    require("simpleCppTreesitterTools").setup({
        verboseNotifications = true,
        })
    vim.keymap.set("n", "<localleader>c", function() vim.cmd("ImplementMembersInClass") end,{desc = 'implement class member declarations in [c]pp file'})
    vim.keymap.set("n", "<localleader>a", function() vim.cmd("ImplementMemberOnCursorLine") end,{desc = 'implement function on current line'})
    vim.keymap.set("n", "<localleader>s", function() vim.cmd("StPatrick") end,{desc = 'drive out the [s]nakes'})
    vim.keymap.set("n", "<localleader>d", function() vim.cmd("CreateDerivedClass") end,{desc = 'Create a class which [d]erives from the current one'})
end
}
```

## Examples and usage

text and mp4s go here!

## Resources to learn from

### Lua and writing plugins


[Neovim lua plugin from scratch](https://www.youtube.com/watch?v=n4Lp4cV8YR0) --- This is my first plugin, and this is where I learned how simple making a plugin could be.

Not going to lie: everything I know about lua came either from [reading the docs](https://www.lua.org/manual/5.1/) and from [TJ](https://www.youtube.com/watch?v=CuWfgiwI73Q). It should be obvious upon inspecting the code that I barely know what I'm doing.

### Treesitter-specific

Documentation for [treesitter](https://tree-sitter.github.io/tree-sitter/) and [neovim's integration of it](https://neovim.io/doc/user/treesitter.html). The first is great for learning how to write queries, the second for understanding some functions for using queries and iterating over matches conveniently.

[The first time I saw treesitter queries](https://www.youtube.com/watch?v=aNWx-ym7jjI)

[Thnks fr th Trsttr](https://m.youtube.com/watch?v=_m7amJZpQQ8)

[refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim)

## Related, and better, plugins

[nvim-treesitter-cpp-tools](https://github.com/Badhi/nvim-treesitter-cpp-tools)
