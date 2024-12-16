# simpleCppTreesitterTools.nvim 

This plugin used to just be a messy lua file in my `/after/ftplugin/` directory. 
When I asked on reddit for [suggestions for cpp plugins](https://www.reddit.com/r/neovim/comments/1h53req/neovim_and_c_luasnip_treesitter_and_reinventing/), it was suggested that
there weren't as many such plugins, or even resources for learning about treesitter's
query system, as I might have expected (but please see the Related Plugins section below).


Hence: a plugin which might be slightly useful when coding, and which might be helpful
to learn a bit about using treesitter queries. 

## Features

This plugin basically does four things.
The main function is `ImplementMembersInClass`, which looks at all of the (possibly templated) member functions in a (possibly templated) class.
It checks whether there are functions that have yet to be implemented in the corresponding `.cpp` file --- including the case that such a file doesn't exist --- and adds an implementation stub.
It even makes a low-effort "best-effort" attempt to keep the definitions in the same order as the declarations.

A specialized version, `ImplementMemberOnCursorLine`, does the same thing but just for whatever line your cursor happens to be on.

A third command, `CreateDerivedClass` creates a new header file with a class which derives from the current class. Virtual functions (or, optionally, only pure virtual functions) in the current class are added as members of the derived class.

Finally, probably most usefully, I've tried to write the code here that it's easy to understand how I'm writing treesitter queries, how I'm parsing them, and how I'm then wrangling those parsed results into my desired results. That's all just a way of saying "this code is not that sophisticated, because I'm not that sophisticated, so it shouldn't be too bad to follow along."


## Installation and Configuration

Using [lazy.nvim](https://github.com/folke/lazy.nvim), installation is just
```lua 
{
    "DanielMSussman/simpleCppTreesitterTools.nvim",
    dependencies = { 'nvim-treesitter/nvim-treesitter'},
    config = function()
        require("simpleCppTreesitterTools").setup()
    end
}
```

There are a small handful of default options that can be changed by passing options to the setup function. A more complete lazy config with all of these options and some suggested keymaps:
```lua

{
    "DanielMSussman/simpleCppTreesitterTools.nvim",
    dependencies = { 'nvim-treesitter/nvim-treesitter'},
    config = function()
        require("simpleCppTreesitterTools").setup({
            headerExtension =".h",
            implementationExtension=".cpp",
            verboseNotifications = true,
            tryToPlaceImplementationInOrder = true,
            onlyDerivePureVirtualFunctions = false,
            dontActuallyWriteFiles = false, -- for testing, of course
        })
        vim.keymap.set("n", "<localleader>c", function() vim.cmd("ImplementMembersInClass") end,{desc = 'implement [c]lass member declarations'})
        vim.keymap.set("n", "<localleader>l", function() vim.cmd("ImplementMemberOnCursorLine") end,{desc = 'implement member current [l]ine'})
        vim.keymap.set("n", "<localleader>s", function() vim.cmd("StPatrick") end,{desc = 'drive out the [s]nakes'})
        vim.keymap.set("n", "<localleader>d", function() vim.cmd("CreateDerivedClass") end,{desc = 'Create a class which [d]erives from the current one'})
    end
}
```

## Examples and usage

text and mp4s go here!

## Resources to learn from

The documentation quality and the available resources to learn from in the (neo)vim community is typically outstanding; here are some of the ones that I found particularly useful..

### Lua and writing plugins

I'm not going to lie: everything I know about Lua comes either from [reading the docs](https://www.lua.org/manual/5.1/) or from [TJ](https://www.youtube.com/watch?v=CuWfgiwI73Q). It should be obvious upon inspecting the code that I barely know what I'm doing.

Also, I've never written a plugin before --- when you first use (neo)vim pluings are mysterious black boxes, and [this video](https://www.youtube.com/watch?v=n4Lp4cV8YR0) helped me learn how simple making a plugin can be.


### Treesitter-specific

The [first time I saw treesitter queries](https://www.youtube.com/watch?v=aNWx-ym7jjI) --- i.e., using treesitter for more than just syntax highlighting --- was when I was learning to write fun luasnip snippets. I filed that away for later, and this plugin grew out of my attempts to finally learn a little bit more.

The documentation for [treesitter itself](https://tree-sitter.github.io/tree-sitter/) is fantastic for learning about the mechanics of writing queries, and the documentation of [neovim's integration of treesitter](https://neovim.io/doc/user/treesitter.html) is helpful for understanding some of the functions of convenience for using those queries and iterating over matches to them.
There are a few spots where the documentation could be a bit more explanatory ("what's the return type of this function? A TSQueryMatch. What is a TSQueryMatch? You'll have to go to a different website's documentation..."), but combining the examples given with a liberal use of `print(vim.inspect())` when experimenting with the code makes it all relatively easy to learn.

When it comes to writing the queries themselves, I can't stress enough how helpful just staring at the syntax tree of a file (`:InspectTree`) and then trying out different queries (`:EditQuery`) is. The fact that this is built into neovim is awesome.

Two other sources that helped me learn more about working with treesitter: this [Thnks fr th Trsttr](https://m.youtube.com/watch?v=_m7amJZpQQ8) video and the [refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim) plugin.


## Related --- almost certainly better! --- plugins

I don't claim any particular originality with this plugin --- I wrote some functions that I found helpful and that gave me an excuse to learn more about a core part of neovim, but I'm hardly the first person to implement a similar set of functions.
Badhi's [nvim-treesitter-cpp-tools](https://github.com/Badhi/nvim-treesitter-cpp-tools) is another treesitter-powered plugin that contains almost a superset of the functions here. It uses somewhat simpler treesitter queries and does more work parsing them in the plugin, whereas I've tended to use a lot more capture groups in my queries so that I have less work to do in the plugin itself.

I recently found this much older plugin that implements *many* more cpp-related features. It ([lh-cpp](https://github.com/LucHermitte/lh-cpp/)) takes a quite different approach to the problem, but I haven't experimented with it too much.

Finally, it's probably important to remember that roughly 90 percent of what this plugin does can be replicated with [sufficiently interesting vim stuff / black magic](https://vi.stackexchange.com/questions/44964/any-c-c-definition-generators-for-vim). 
