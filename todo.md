# Global to-do list

## reasonable priority

Derive class -- add all virtual functions to the header (option: only add pure virtual functions)
    - [ ] parse pure virtual nodes (pureVirtualFunctionQuery)
    - [ ] parse all virtual nodes (pureVirtualKeywordQuery? or look at the starting point of the field declaration, and see if the type starts at the same column or not)

## reasonably low priority

more sophisticated alternate file (hxx,cxx,etc)

if the same header file has multiple classes, and some of the member functions have the same set of arguments, those functions won't be implemented (current "does implementation exist in the file" doesn't test for the classname)

rule of 3 / 5? Just use or look at [nvim-treesitter-cpp-tools](https://github.com/Badhi/nvim-treesitter-cpp-tools). That's probably good advice for all of the functionality in this plugin.

