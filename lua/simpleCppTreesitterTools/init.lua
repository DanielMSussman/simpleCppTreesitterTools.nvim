-- cppModule has all of the "interesting" functions
local cppModule = require("simpleCppTreesitterTools.cppModule")
-- reading and writing files? parsing filenames? Ugh. Have a helper do the dirty work
local helperBot = require("simpleCppTreesitterTools.fileHelpers")

local M = {}

M.config = {
    headerExtension =".h",
    implementationExtension=".cpp",
    verboseNotifications = true,
    tryToPlaceImplementationInOrder = true,
    onlyDerivePureVirtualFunctions = false,
    dontActuallyWriteFiles = false, -- for testing, of course
}
M.data = {
    headerFile ="",
    implementationFile="",
}
--pass in plugin config options, and define user commands
M.setup = function(opts)
    M.config = vim.tbl_deep_extend("force",M.config,opts or {})
    print(vim.inspect(M.config))
    cppModule.config = M.config

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

--[[
This function should be called from the buffer corresponding to the header.
It will set the path to the implementation file, and create that file 
if it doesn't exist
]]--
M.setCurrentFiles = function()
    M.data.headerFile, M.data.implementationFile = helperBot.getAbsoluteFilenames(M.config.headerExtension,M.config.implementationExtension) 

    cppModule.data = M.data
    helperBot.createIncludingFileIfItDoesNotExist(M.data.implementationFile)
end

--[[
Attempts to find all implementable nodes (functions, template functions, 
constructors, etc...), add them to them to the corresponding cpp file 
(creating that file if it doesn't exist).
Tries to check if a function has already been implemented (so that there
are not repeated implementations, and will try (by default) to put 
functions in the cpp file in the same order they appear in the header file
]]--
M.implementMembersInClass = function()
    M.setCurrentFiles()
    cppModule.addImplementationsToCPP()
    helperBot.refreshImplementationBuffer(M.data.implementationFile)
end

--[[
Same as the implementMembersInClass function, but rather than adding all functions,
only tries to add the function on the same line as the cursor.
Note that for templated functions, the cursor needs to be on the function declaration line 
(and not on the template<typename...> line)
]]--
M.implementFunctionOnLine = function()
    M.setCurrentFiles()
    cppModule.addImplementationOnCurrentLine()
    helperBot.refreshImplementationBuffer(M.data.implementationFile)
end

--[[
Looks for variables or function parameters that are in snake_case formatting,
and then jumps the cursor to the next line containing one.
Why? Why not.
]]--
M.whereAreTheSnakeCaseVariables = function()
    cppModule.huntForSnakeCaseVariables()
end

--[[
Take the current header file, and then create a new header file with a class that derives from it.
If there are pure virtual functions (or, by config option, *any* virtual functions),
add them as part of the new header file.
]]--
M.createDerivedClass = function()
    M.data.headerFile, M.data.implementationFile = helperBot.getAbsoluteFilenames(M.config.headerExtension,M.config.implementationExtension) 
    cppModule.data =M.data
    cppModule.createDerivedClass()
end

return M
