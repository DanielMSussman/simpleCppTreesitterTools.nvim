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
 take a "signature" (the string we want to associated with the functions in the header file),
and format an implementation stub around it. Hope you like Whitesmiths!
--]]
M.appendFormatedSignatureToTable = function(contentToAppend,signature)
    table.insert(contentToAppend,"")
    for i, line in ipairs(signature) do 
        table.insert(contentToAppend, line)
    end
    table.insert(contentToAppend, "    {")
    table.insert(contentToAppend, "    }")
end

--return the function type and the proper node
M.determineFunctionType = function(node)
    --If the user is on the template line, the node itself will be a templateDecl
    if node:type() == "template_declaration" then
        return node, "templatedFunction"
    end
    -- if the user is at the beginning of a virtual function, they're already at a field_declaration
    if node:type() == "field_declaration" then
        return node, "standardFunction"
    end
    if node:type() == "declaration" then
        return node, "constructorLike"
    end

    -- local parent = node:parent()
    -- if parent:type() == "function_declarator" then
    --     return parent, "constructorLike"
    -- end
    -- if parent:type() == "field_declaration" then
    --     return parent,"standardFunction"
    -- end

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

    return className, classNode
end



M.stripDefaultArgumentsFromParameterList = function(functionNode)

    local argumentTable = treesitterUtilities.getArgumentTableWithoutDefaults(functionNode)

    if argumentTable[1] ==0 then
        return "()"
    end
    local parameterListString = "("

    for i, line in ipairs(argumentTable[2]) do 
        if i < argumentTable[1] then
            parameterListString = parameterListString..line[1].." "..line[2]..", "
        else
            parameterListString = parameterListString..line[1].." "..line[2]..")"
        end
    end
    return parameterListString
end

M.constructImplementationStringFromNode = function(currentNode,nodeFlavor,className)
    local implementationString = nil
    local parameterListString = M.stripDefaultArgumentsFromParameterList(currentNode)

    if nodeFlavor == "standardFunction" then
        local typeString,functionString = treesitterUtilities.parseFunctionNodeTypeAndName(currentNode)

        implementationString = {typeString.." "..className.."::"..functionString..parameterListString}
        return implementationString
    end
    if nodeFlavor == "templatedFunction" then
        local templateString,typeString,functionString = treesitterUtilities.parseTemplateFunction(currentNode)
        implementationString = {templateString,typeString.." "..className.."::"..functionString..parameterListString}
        return implementationString
    end
    if nodeFlavor == "constructorLike" then
        local classFunctionString = treesitterUtilities.parseConstructorLikeFunction(currentNode)
        implementationString = {className.."::"..classFunctionString..parameterListString}
        return implementationString
    end

    -- vim.notify(implementationString)
    return implementationString
end

M.testForImplementationInFile = function(implementationString)
    local fileContent = vim.fn.readfile(M.data.implementationFile)
    if not fileContent then
        return nil
    end

    local tableLength = treesitterUtilities.getTableLength(implementationString)
    local matchString = false
    for i, line in ipairs(fileContent) do
        if line== implementationString[1] then
            matchString = true
            for j = 2, tableLength, 1 do
                if fileContent[i+j-1] ~= implementationString[j] then 
                    matchString = false
                end
            end
        end
        if matchString then
            return i
        end
    end
    return nil
end

M.insertLinesIntoFile = function(filename, lines, lineNumber)
    local file_content = vim.fn.readfile(filename)

    -- Insert the new lines at the specified line number
    if lineNumber  > 0 and lineNumber <= #file_content then
        for i = #lines, 1, -1 do
            table.insert(file_content, lineNumber, lines[i])
        end
    else
        -- If lineNumber is beyond the end of the file, append the lines
        vim.list_extend(file_content, lines)
    end

    -- Write the modified content back to the file
    vim.fn.writefile(file_content, filename)
end

M.writeNodeToFile = function(node,nodeFlavor,className)
    local implementationString = M.constructImplementationStringFromNode(node,nodeFlavor,className)
    local implementationStub = {}
    M.appendFormatedSignatureToTable(implementationStub,implementationString)
    local implementationExistsOnLineNumber = M.testForImplementationInFile(implementationString)

    -- print(vim.inspect(implementationStub))
    -- vim.notify(implementationString)

    if implementationExistsOnLineNumber then
        if M.config.verboseNotifications then
            vim.notify(table.concat(implementationString,"\n").." already exists in file")
        end
        return
    end

    if M.config.tryToPlaceImplementationInOrder then 
        M.implementNodeInFileSorted(node,flavor,className,implementationString,implementationStub)
    else
        vim.fn.writefile(implementationStub,M.data.implementationFile,"a")
    end
end

M.getNextSiblingLocationInFile = function(currentNode,className)
    local nextSibling = treesitterUtilities.getNextSibling(currentNode)

    while nextSibling do 
        while treesitterUtilities.siblingToSkip(nextSibling) do 
            nextSibling = treesitterUtilities.getNextSibling(nextSibling)
        end

        local siblingNode, siblingNodeFlavor = M.determineFunctionType(nextSibling)
        local siblingString = M.constructImplementationStringFromNode(siblingNode,siblingNodeFlavor,className)
        local locationInFile = M.testForImplementationInFile(siblingString)
        if locationInFile then
            return nextSibling, locationInFile
        else
            nextSibling = treesitterUtilities.getNextSibling(nextSibling)
        end
    end

    return nil, nil
end

--[[
A very low-effort "best-effort" attempt to add the function in the right spot
in the cpp file. No promises, will fail if the next line is a member variable,
or a comment, or anything other than what this plugin deals with.
Approach: see if the string that would have been written for the next child node 
]]--
M.implementNodeInFileSorted = function(currentNode,nodeFlavor,className,implementationString,implementationStub)

    --try our best to find the next that's been implemented, and insert before it
    local nextImplementedSibling, lineToInsert = M.getNextSiblingLocationInFile(currentNode,className)

    if not nextImplementedSibling then
        vim.fn.writefile(implementationStub,M.data.implementationFile,"a")
        return
    end

    if not lineToInsert then
        M.insertLinesIntoFile(M.data.implementationFile,implementationStub,-1)
        lineToInsert = -1
    else
        M.insertLinesIntoFile(M.data.implementationFile,implementationStub,lineToInsert-1)
    end

end


M.addImplementationOnCurrentLine = function()

    local className, classNode  = M.determineLocalClass()
    if not classNode then
        return
    end
    local currentNode = vim.treesitter.get_node()
    local nodeFlavor = nil
    --test for function / template / constructor distinctions by looking at parent nodes
    local isFunction = treesitterUtilities.getNamedAncestor(currentNode,"field_declaration")
    local isTemplate = treesitterUtilities.getNamedAncestor(currentNode,"template_declaration")
    local isConstructor = treesitterUtilities.getNamedAncestor(currentNode,"declaration")

    if isFunction then
        currentNode = isFunction
        nodeFlavor = "standardFunction"
    elseif isTemplate then
        currentNode = isTemplate
        nodeFlavor = "templatedFunction"
    elseif isConstructor then -- it's a bit janky... isConstructor will also be true for templated member functions
        currentNode = isConstructor
        nodeFlavor = "constructorLike"
    end

    if not nodeFlavor then
        if(M.config.verboseNotifications) then
            vim.notify("Cursor not in or on a line with a function")
        end
        return
    end
    M.writeNodeToFile(currentNode,nodeFlavor,className)
end

M.appendAllImplementationsToCPP = function()

    local className, classNode  = M.determineLocalClass()
    if not classNode then
        return
    end

    local nodeTable = treesitterUtilities.getImplementableFields(classNode)
    -- nodeTable = treesitterUtilities.getAllImplementableFields(classNode)
    --
    -- for i, tableItems in ipairs(nodeTable) do 
    --     local node = tableItems[2]
    --     local flavor = tableItems[1]
    --     M.writeNodeToFile(node,flavor,className)
    -- end
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
        -- vim.api.nvim_win_set_cursor(0, {target,0})
        vim.api.nvim_win_set_cursor(0, target)
    end
end

M.createDerivedClass = function()
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
    
    -- to start, include the base class header
    helperBot.createIncludingFileIfItDoesNotExist(newFileName)
    local contentToAppend = {}
    table.insert(contentToAppend,"")
    table.insert(contentToAppend,"/*!")
    table.insert(contentToAppend,"This class, inheriting from "..className.."...")
    table.insert(contentToAppend,"*/")
    table.insert(contentToAppend,"class "..newClassName.." : public "..className)
    table.insert(contentToAppend,"    {")
    table.insert(contentToAppend,"    public:")
    table.insert(contentToAppend,"")
    table.insert(contentToAppend,"    };")

    vim.fn.writefile(contentToAppend,newFileName,"a")

end

return M
