local treesitterUtilities = require("simpleCppTreesitterTools.simpleTreesitterUtilities")
local helperBot = require("simpleCppTreesitterTools.fileHelpers")
local M = {}

M.data = {
    headerFile ="",
    implementationFile="",
}

M.config = {
    verboseNotifications = true,
    tryToPlaceImplementationInOrder = true,
    headerExtension =".h",
    implementationExtension=".cpp",
}


--[[
build up the set of strings that will be added to the file
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



M.writeImplementationInFileSorted = function(implementationContent,nodeTable,i)
    local lineTarget  = -1
    for loopIndex = i+1,#nodeTable do 
        local nodeBatch = nodeTable[loopIndex]
        local functionName = nodeBatch[3]
        local listOfParameterTypes = nodeBatch[5]
        local alreadyImplemented,lineNumber = treesitterUtilities.testImplementationFileForFunction(functionName,listOfParameterTypes,M.data.implementationFile)
        if alreadyImplemented then
            lineTarget = lineNumber 
            break
        end
    end
    helperBot.insertLinesIntoFile(M.data.implementationFile,implementationContent,lineTarget)
end

M.writeImplementationToFile = function(implementationContent, nodeTable,i)

    if M.config.tryToPlaceImplementationInOrder then 
        M.writeImplementationInFileSorted(implementationContent,nodeTable,i)

    else
        vim.fn.writefile(implementationContent, M.data.implementationFile,"a")
    end

end


M.addImplementationOnCurrentLine = function()
    local currentCursorLine = vim.api.nvim_win_get_cursor(0)[1]
    M.addImplementationsToCPP(currentCursorLine)
end

M.addImplementationsToCPP = function(lineNumberRestriction)

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

        if lineNumberRestriction and lineNumberRestriction ~= nodeLineNumber then
            goto continue
        end
        local alreadyImplemented = treesitterUtilities.testImplementationFileForFunction(functionName,listOfParameterTypes,M.data.implementationFile)

        if alreadyImplemented then
            if M.config.verboseNotifications then
                vim.notify(functionName.." with that argument list already exists in file")
            end
        else
            local implementationContent = M.constructImplementationTable(returnTypeString,className,functionName,parameterListString,postTypeKeywordString,templateString,classTemplateString,functionNode)
            --in addition to the content to be added to the file, pass information that can 
            --be used to put implementations in the same order as in the header file
            M.writeImplementationToFile(implementationContent,nodeTable, i)
        end
        ::continue::
    end
end

M.huntForSnakeCaseVariables = function()
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

M.createDerivedClass = function(onlyAddVirtalFunctions)
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
    local newFileName = vim.fn.expand("%:h").."\\"..newClassName..M.config.headerExtension
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
    table.insert(contentToAppend,"This class, inheriting from "..className.."...")
    table.insert(contentToAppend,"*/")
    table.insert(contentToAppend,"class "..newClassName.." : public "..className)
    table.insert(contentToAppend,"    {")
    table.insert(contentToAppend,"    public:")
    table.insert(contentToAppend,"")

    for i, node in ipairs(virtualNodes) do 
        local pureVirtual = node[2]
        local virtualString = node[1]
        if not onlyAddVirtalFunctions then
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
