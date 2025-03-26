# simpleCppTreesitterTools.nvim 


https://github.com/user-attachments/assets/ba249933-39eb-4fbf-b7bf-81158d550322

This small project started as a messy lua file in my `/after/ftplugin/` directory. 
When I asked on reddit for [suggestions for cpp plugins](https://www.reddit.com/r/neovim/comments/1h53req/neovim_and_c_luasnip_treesitter_and_reinventing/), it was suggested that
there weren't as many such plugins --- or resources for learning about treesitter's
query system --- as I might have expected (but please see the Related Plugins section below).


Hence: I turned that messy lua file into a plugin which might be slightly useful when coding, and which I hope is helpful for those who want to learn a bit more about integrating custom treesitter into their neovim experience.

## Features

This plugin basically does four things.

The main command is `ImplementMembersInClass`, which looks at all of the (possibly templated) member functions in a (possibly templated) class.
It checks whether there are functions that have yet to be implemented in the corresponding `.cpp` file --- including the case that such a file doesn't exist --- and adds an implementation stub.
It further makes a low-effort "best-effort" attempt to keep the definitions in the same order as the declarations.

The `ImplementMemberOnCursorLine` command, does the same thing but just for whatever line your cursor happens to be on.

A third command, `CreateDerivedClass` creates a new header file with a class which derives from the current class. Virtual functions (or, optionally, only pure virtual functions) in the current class are added as members of the derived class.

Finally, probably most usefully, I've tried to write the code here that it's easy to understand how I'm writing treesitter queries, how I'm parsing them, and how I'm then wrangling those parsed results into my desired results. I took notes while I was learning all of this myself, and summarized some tips [here](/doc/queriesParsingAndProcessingMatches.md).



## Installation, Configuration, and Requirements

Please note that a breaking change was introduced in Neovim 0.11 (related to the way that matches to a query are iterated through). If you are using an older version of neovim, please checkout the commit with the `nvim0.10compatible` tag.

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
    ft = "cpp",
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
        vim.keymap.set("n", "<localleader>l", function() vim.cmd("ImplementMemberOnCursorLine") end,{desc = 'implement member on current [l]ine'})
        vim.keymap.set("n", "<localleader>s", function() vim.cmd("StPatrick") end,{desc = 'drive out the [s]nakes'})
        vim.keymap.set("n", "<localleader>d", function() vim.cmd("CreateDerivedClass") end,{desc = 'Create a [d]erived class from the current one'})
    end
}
```

## Examples and usage

### ImplementMembersInClass

Running the primary function on a header file when the `.cpp` file doesn't exist, we end up with a proper set of implementation stubs for everything we want (constructors, functions, templated functions) and not for things we don't want (functions defined in the header itself and pure virtual functions).
The function does its best to handle nested templates, constness, constexpr, and other language features that I use. Well, I don't actually use constexpr that much, but people tell me I should.

https://github.com/user-attachments/assets/40f694ff-121e-4e14-a02c-ab5197518699



### ImplementMemberOnCursorLine

One could obtain the same outcome as above by running the `ImplementMemberOnCursorLine` function with your cursor on the line of each desired function.
Additionally, as soon as the `.cpp` file exists, the new implementation stub --- using either this and the more general command --- gets put in the same order as it appears in the header.

https://github.com/user-attachments/assets/14c79378-2023-4abe-9276-6b4c4ee63eed

### CreateDerivedClass

When `CreateDerivedClass` is called from inside a class declaration in a header file, you are prompted for a new class name. A header file with that name is generated, and it is filled with a declaration of the new class (which comes pre-populated with virtual functions from the original class).

https://github.com/user-attachments/assets/0d72bc96-1ea8-49e0-8a7c-a3238ccc6452

## Resources to learn from

The documentation quality and the available resources to learn from in the (neo)vim community is typically outstanding.
Below I've listed some of the ones that I found particularly useful, and I've tried to distill the essence of what I've learned about working with treesitter queries [in this documentation file](/doc/queriesParsingAndProcessingMatches.md).

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

I recently found an older plugin that implements *many* more cpp-related features. [lh-cpp](https://github.com/LucHermitte/lh-cpp/) takes a quite different approach to the problem, and I haven't experimented with it too much. Looks interesting.

Finally, it's probably important to remember that roughly 90 percent of what this plugin does can be replicated with [sufficiently interesting vim stuff / black magic](https://vi.stackexchange.com/questions/44964/any-c-c-definition-generators-for-vim). 100 percent could be done by combining ideas like this with a willingness to just type more characters.
