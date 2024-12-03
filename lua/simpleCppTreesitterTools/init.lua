-- cppModule has all of the "interesting" functions
local cppModule = require("simpleCppTreesitterTools.cppModule")
-- reading and writing files? parsing filenames? Ugh. Have helperBot do the dirty work
local helperBot = require("simpleCppTreesitterTools.fileHelpers")

--[[
Global to-do list:
   
   refactor everything using the findNonPureVirtualMembers query (should make life easier
        better handling of templates: given a templateOrConstructorDeclaration, check if the near-parent is a template. Check if the class has a template

    Derive class -- add all virtual functions to the header (option: only add pure virtual functions)
        parse pure virtual nodes (pureVirtualFunctionQuery)
        parse all virtual nodes (pureVirtualKeywordQuery? or look at the starting point of the field declaration, and see if the type starts at the same column or not)

    const functions: check if they have a type_qualifer as child of the declarator

    static: check for (storage_class_specifier) node as sibling prior to type

    snake hunting in header files
    testForImplementationInFile would be better as a node query on the cpp file, rather than "is this string what the plugin would have written?"

    classes that are themselves templated: not currently handled

    more sophisticated alternate file

--]]


local M = {}

M.config = {
    verboseNotifications = true,
    tryToPlaceImplementationInOrder = true,
}
M.data = {
    headerFile ="",
    implementationFile="",
}

M.setup = function(opts)
    M.config = vim.tbl_deep_extend("force",M.config,opts or {})
    cppModule.config.verboseNotifications = M.config.verboseNotifications
    cppModule.config.tryToPlaceImplementationInOrder = M.config.tryToPlaceImplementationInOrder

    --set some user commands for convenience?
    
    vim.api.nvim_create_user_command("ImplementMembersInClass",
        function()
            require("simpleCppTreesitterTools").implementMembersInClass()
        end,{desc = 'attempt to implement everything in the class'}
    )
    vim.api.nvim_create_user_command("ImplementMemberOnCursorLine",
        function()
            require("simpleCppTreesitterTools").implementFunctionOnLine()
        end,{desc = 'attempt to implement the member function on the current line'}
    )
    vim.api.nvim_create_user_command("CreateDerivedClass",
        function()
            require("simpleCppTreesitterTools").createDerivedClass()
        end,{desc = 'make a new file with a class that inherits from the current one'}
    )
    vim.api.nvim_create_user_command("StPatrick",
        function()
            require("simpleCppTreesitterTools").whereAreTheSnakeCaseVariables()
        end,{desc = 'a function of convenience'}
    )
end

M.createDerivedClass = function()
    M.data.headerFile, M.data.implementationFile = helperBot.getAbsoluteFilenames() 

    cppModule.data.headerFile = M.data.headerFile
    cppModule.data.implementationFile = M.data.implementationFile
    cppModule.createDerivedClass()
end

--This function should be called from the buffer corresponding to the header. It will set the path to the implementation file, and create that file if it doesn't exist
M.setCurrentFiles = function()
    M.data.headerFile, M.data.implementationFile = helperBot.getAbsoluteFilenames() 

    cppModule.data.headerFile = M.data.headerFile
    cppModule.data.implementationFile = M.data.implementationFile
    helperBot.createIncludingFileIfItDoesNotExist(M.data.implementationFile)
    -- vim.api.nvim_command('edit ' .. M.data.implementationFile)
    -- vim.api.nvim_command('stopinsert') 
end

M.implementMembersInClass = function()
    M.setCurrentFiles()
    cppModule.appendAllImplementationsToCPP()
    helperBot.refreshImplementationBuffer(M.data.implementationFile)
end

M.implementFunctionOnLine = function()
    M.setCurrentFiles()
    cppModule.addImplementationOnCurrentLine()
    helperBot.refreshImplementationBuffer(M.data.implementationFile)
end

M.whereAreTheSnakeCaseVariables = function()
    cppModule.huntForSnakeCaseVariables()
end

return M
