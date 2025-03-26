-- local treesitterUtilities = require("simpleCppTreesitterTools.simpleTreesitterUtilities")
local treesitterUtilities = nil
local helperBot = require("simpleCppTreesitterTools.fileHelpers")
local M = {}

--will be set on call to init.lua's setCurrntFiles()
M.data = {
    headerFile ="",
    implementationFile="",
}

--will be set during plugin setup
M.config = {
}

--[[
load treesitterUtilities (i.e., require the file that has all of the parsing queries) only when called
I'm not exactly sure if I'm doing the *.scm file stuff correctly, but clearly
loading / parsing the queries is slowing down the loading of the plugin.
This function moves that slow-down just to the first time a cppModule function is invoked from the init.lua file
]]--
M.loadTreesitterUtilities = function()
    if not treesitterUtilities then
        treesitterUtilities = require("simpleCppTreesitterTools.simpleTreesitterUtilities")
    end
end

--[[
build up the set of strings that will be added to the implementation file,
based on the various parsing actions done.
Hope you like Whitesmiths!
]]--
M.constructImplementationTable = function(returnTypeString,className,functionName,parameterListString,postTypeKeywordString,functionTemplateString,classTemplateString,functionNode)
    -- destructors weren't covered in the original "non-pure-virtual" query, and I don't want to re-write it...
    local functionSignature = className.."::"..functionName..parameterListString
    if returnTypeString then
        functionSignature = returnTypeString.." "..functionSignature
    end
    if postTypeKeywordString then
        functionSignature = functionSignature.." "..postTypeKeywordString
    end
    local implementation = {}
    table.insert(implementation,"")

    if classTemplateString then
    table.insert(implementation,classTemplateString)
    end
    -- there's a bit of remaining jank in how we're capturing templates... we need to distinguish template functions from potentially templated classes
    if(functionTemplateString and functionNode:parent():type() == "declaration") and functionNode:parent():parent():type() == "template_declaration" then
        table.insert(implementation,functionTemplateString)
    end

    table.insert(implementation,functionSignature)
    table.insert(implementation, "    {")
    table.insert(implementation, "    }")
    return implementation
end

--[[
From the cursor position, climb up the syntax tree to discover what class we are in.
Deduce, as necessary, any class template information
]]--
M.determineLocalClass = function()
    -- get the class specifier we're sitting inside of
    local currentNode = vim.treesitter.get_node()
    local classNode = treesitterUtilities.getNamedAncestor(currentNode,'class_specifier')

    if not classNode then
        if(M.config.verboseNotifications) then
            vim.notify('Not inside a class')
        end
        return nil
    end


    local className=""

    for i = 0, classNode:named_child_count()-1, 1 do
        local childNode = classNode:named_child(i)
        if childNode:type() == 'type_identifier' then
            className = vim.treesitter.get_node_text(childNode,0)
            break
        end
    end

    if classNode:parent():type() == "template_declaration" then
        classTemplateString,classAngleBrackets = treesitterUtilities.getClassTemplateInformation(classNode:parent())
    end

    return className, classNode, classTemplateString, classAngleBrackets
end



--[[
Interface with the treesitterUtilities functions to try to figure out where the implementation
should be placed in the cpp file.
Ideally, the cpp file has declaration in the same order as the header file (?),
and we do this by scanning the table of nodes in the header for nodes 
after the current target to see if their implementation exists already.
]]--
M.writeImplementationInFileSorted = function(implementationContent,nodeTable,i,className)
    local lineTarget  = -1
    for loopIndex = i+1,#nodeTable do 
        local nodeBatch = nodeTable[loopIndex]
        local functionName = nodeBatch[3]
        local listOfParameterTypes = nodeBatch[5]
        local alreadyImplemented,lineNumber = treesitterUtilities.testImplementationFileForFunction(functionName,listOfParameterTypes,className,M.data.implementationFile)
        if alreadyImplemented then
            lineTarget = lineNumber 
            break
        end
    end
    helperBot.insertLinesIntoFile(M.data.implementationFile,implementationContent,lineTarget,M.config.dontActuallyWriteFiles)
end

--[[
Depending on the plugin config, either append the implementation to the end of the file or 
try to keep the cpp file implementations in the same order as the header
]]--
M.writeImplementationToFile = function(implementationContent, nodeTable,i,className)

    if M.config.tryToPlaceImplementationInOrder then 
        M.writeImplementationInFileSorted(implementationContent,nodeTable,i,className)

    else
        if not M.config.dontActuallyWriteFiles then
            vim.fn.writefile(implementationContent, M.data.implementationFile,"a")
        end
    end

end


--[[
For simplicity, adding the implementation on the current cursor line calls the 
"implementEverything" functions below, but then filters the table of nodes based on the 
position of the cursor.
This is useful given how I've implemented the "try to keep the cpp file sorted" logic
]]--
M.addImplementationOnCurrentLine = function()
    M.loadTreesitterUtilities()
    local currentCursorLine = vim.api.nvim_win_get_cursor(0)[1]
    -- print(vim.inspect(currentCursorLine))
    M.addImplementationsToCPP(currentCursorLine)
end

--[[
The driver function of this plugin. First, it determines information about the class the cursor is inside of.
It then uses treesitterUtilities to get a table containing function nodes (and other pre-parsed information
about the relevant strings) of functions in the header.
It does its best to check if those functions are already implemented in the cpp file, and if not it adds them.
The function argument is a line number --- if this is not nil then only nodes 
whose starting line number is on the function argument will be a potential target of implementation
]]--
M.addImplementationsToCPP = function(lineNumberRestriction)
    M.loadTreesitterUtilities()

    local className, classNode,classTemplateString,classAngleBrackets  = M.determineLocalClass()
    if not classNode then
        return
    end
    if classAngleBrackets then
        className = className..classAngleBrackets
    end
    local nodeTable = treesitterUtilities.getImplementableFields(classNode)
    for i, nodeBatch in ipairs(nodeTable) do 
        local functionNode = nodeBatch[1]
        local returnTypeString = nodeBatch[2]
        local functionName = nodeBatch[3]
        local parameterListString = nodeBatch[4]
        local listOfParameterTypes = nodeBatch[5]
        local postTypeKeywordString = nodeBatch[6]
        local templateString = nodeBatch[7]
        local nodeLineNumber = nodeBatch[8]

        -- just hackily skip most of the work if we only want to implement one function
        if lineNumberRestriction and lineNumberRestriction ~= nodeLineNumber then
            goto continue
        end

        local alreadyImplemented = treesitterUtilities.testImplementationFileForFunction(functionName,listOfParameterTypes,className,M.data.implementationFile)

        if alreadyImplemented then
            if M.config.verboseNotifications then
                vim.notify(functionName.." with that argument list already exists in file")
            end
        else
            local implementationContent = M.constructImplementationTable(returnTypeString,className,functionName,parameterListString,postTypeKeywordString,templateString,classTemplateString,functionNode)
            --in addition to the content to be added to the file, pass information that can 
            --be used to put implementations in the same order as in the header file
            if M.config.verboseNotifications then
                vim.notify("implementing "..functionName)
            end
            M.writeImplementationToFile(implementationContent,nodeTable, i,className)
        end
        ::continue::
    end
end

--[[
Make use of the simple query and parsing to find any variable or function argument written with a snake_case name.
Each invocation of this function jumps the cursor to the next instance, looping from the last entry to the first.
]]--
M.huntForSnakeCaseVariables = function()
    M.loadTreesitterUtilities()
    local snakeLines = treesitterUtilities.snakeCaseHunting()

    if #snakeLines == 0 then
        if M.config.verboseNotifications then
            vim.notify("No snakes!")
        end
        return
    end
    local currentCursorLine = vim.api.nvim_win_get_cursor(0)[1]
    local target = nil

    if currentCursorLine < snakeLines[1][1] then
        target = {snakeLines[1][1],snakeLines[1][2]}
    elseif currentCursorLine > snakeLines[#snakeLines][1] then
        target = {snakeLines[#snakeLines][1],snakeLines[#snakeLines][2]}
    else
        local foundCurrent = nil
        for i = 1, #snakeLines do
            if foundCurrent and snakeLines[i][1]~= currentCursorLine then
                target = {snakeLines[i][1],snakeLines[i][2]}
                break
            end

            if snakeLines[i][1] >= currentCursorLine then
                foundCurrent = true
            end
        end
        if not target and foundCurrent and snakeLines[1][1] ~= currentCursorLine then
            target = {snakeLines[1][1],snakeLines[1][2]}
        end

    end
    if target then
        vim.api.nvim_win_set_cursor(0, target)
    end
end

--[[
First, makes sure that the cursor is inside of a class.
The user is then prompted for a new class name; a new header file implementing a basic
    include parentClass.h 
    class derivedClass : public parentClass
pattern is created.
Any pure virtual functions in the parent will be added to the new header. A 
configuration option can be set so that *all* virtual functions in the parent are added, too.
]]--
M.createDerivedClass = function()
    M.loadTreesitterUtilities()
    -- make sure we're already in a class
    local className, classNode  = M.determineLocalClass()
    if not classNode then
        return
    end
    -- prompt for the new class' name, and make sure it doesn't already exist
    local newClassName = nil
    vim.ui.input({ prompt = 'Enter name for derived class: ' }, function(input)
        newClassName  = input
    end)
    if newClassName == "" then
        if M.config.verboseNotifications then
            vim.notify("No class name entered... exiting function now")
        end
        return
    end
    local newFileName = vim.fn.expand("%:h").."/"..newClassName..M.config.headerExtension

    if vim.fn.filereadable(newFileName) == 1 then
        vim.notify("A file with the target name already exists... exiting function now")
        return
    end

    --start out by getting virtual functions in the current header
    virtualNodes = treesitterUtilities.findVirtualNodes(classNode)

    -- start building up the file to write
    local contentToAppend = {}
    table.insert(contentToAppend,"")
    table.insert(contentToAppend,"/*!")
    table.insert(contentToAppend,"This class, inheriting from "..className..", ...")
    table.insert(contentToAppend,"*/")
    table.insert(contentToAppend,"class "..newClassName.." : public "..className)
    table.insert(contentToAppend,"    {")
    table.insert(contentToAppend,"    public:")
    table.insert(contentToAppend,"")

    for i, node in ipairs(virtualNodes) do 
        local pureVirtual = node[2]
        local virtualString = node[1]
        if not M.config.onlyDerivePureVirtualFunctions then
            table.insert(contentToAppend,virtualString)
            table.insert(contentToAppend,"")
        elseif pureVirtual then
            table.insert(contentToAppend,virtualString)
            table.insert(contentToAppend,"")
        end
    end
    table.insert(contentToAppend,"    };")


    --this function call (a) adds header guards and an endif at the end, (b) includes the current header, and (c) sticks all of the above content in the middle of the file 
    contentToAppend = helperBot.createDerivedFileWithHeaderGuards(newFileName,contentToAppend)

end

return M
