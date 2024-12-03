local localQueries = require("simpleCppTreesitterTools.customTreesitterQueries")

local M= {}

local getNodeText = function(n,bufferNumber)
    return vim.treesitter.get_node_text(n,bufferNumber or 0)
end

M.getTableLength =function(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

M.siblingToSkip = function(node)
    if not node then 
        return false
    end
    if node:type() == "access_specifier" then
        return true
    end
    if node:type() == "comment" then
        return true
    end

    --run a query on field_declarations to see if they are, in fact, variables rather than functions
    if node:type() == "field_declaration" then
        local query = localQueries.testForFieldIdentifier
        for id, node, metadata, match in query:iter_captures(node, 0) do
            local name = query.captures[id]
            if name == "fieldId" then
                return true
            end
        end
    end
    return false
end


M.getNextSibling = function(node)
    local parent = node:parent()
    if not parent then
        return nil  -- no parent = no siblings
    end
    for i = 0, parent:named_child_count() - 1 do
        local child = parent:named_child(i)
        if child == node then
            if i < parent:named_child_count() - 1 then
                return parent:named_child(i + 1)
            else
                return nil  -- No next sibling
            end
        end
    end

    return nil-- Would only get here if the node is not in the parent's set of children, which would be quite strange
end

M.getNamedAncestor = function(inputNode, nodeType)
    local currentNode = inputNode
    while currentNode do
        if currentNode:type() == nodeType then
            break
        end
        currentNode = currentNode:parent()
    end

    return currentNode
end

M.getAllImplementableFields = function(classNode)
    local query = localQueries.constructorFunctionTemplateQuery
    local nodeFlavor = nil
    local tableOfNodes = {}


    for id, node, metadata, match in query:iter_captures(classNode, 0) do
        local name = query.captures[id]
        if name == "classDecl" then 
            nodeFlavor = "constructorLike"
            table.insert(tableOfNodes,{nodeFlavor, node})
        end
        if name == "templateDecl" then
            nodeFlavor = "templatedFunction"
            table.insert(tableOfNodes,{nodeFlavor, node})
        end
        if name == "funcDecl" then
            nodeFlavor = "standardFunction"
            table.insert(tableOfNodes,{nodeFlavor, node})
        end
    end
    return tableOfNodes
end

M.captureTypeAndFunctionName = function(query,queryIterCaptures)
    local typeString, nameString, typeAdditionString = nil,nil,""
    for id, node, metadata, match in queryIterCaptures do
        local name = query.captures[id]
        if name == "primitiveType" or name == "typeIdentifier" or name == "qualifiedType" then
            typeString = vim.treesitter.get_node_text(node,0) 
        else
            nameString = vim.treesitter.get_node_text(node,0) 
        end
        if name == "referenceFunction" then
            typeAdditionString = "&"
        end
        if name == "pointerFunction" then
            typeAdditionString = "*"

        end
    end
   return typeString..typeAdditionString, nameString 
end

M.parseConstructorLikeFunction = function(classDeclarationNode)
    local query = localQueries.constructorLikeNameQuery
    local iterCaptures = query:iter_captures(classDeclarationNode,0)
    local classFunctionString = nil

    for id, node, metadata, match in iterCaptures do
        local name = query.captures[id]
        if name == "classConstructorIdentifier" or name == "classDestructorName" then
            classFunctionString = vim.treesitter.get_node_text(node,0) 
        end
    end
    return classFunctionString
end

M.parseTemplateFunction = function(node)
    local query = localQueries.templateDeclarationFunctionNameQuery
    local typeString, nameString,templateString = nil,nil,nil
    local iterCaptures = query:iter_captures(node,0)
    typeString, nameString = M.captureTypeAndFunctionName(query,iterCaptures)

    for id, node, metadata, match in query:iter_captures(node,0) do
        local name = query.captures[id]
        if name == "templateList" then
            templateString = "template"..vim.treesitter.get_node_text(node,0) 
        end
    end
    return templateString,typeString,nameString
end

M.parseFunctionNodeTypeAndName = function(node)
    local query = localQueries.fieldDeclarationFunctionNameQuery
    local typeString, nameString= nil,nil
    typeString, nameString = M.captureTypeAndFunctionName(query,query:iter_captures(node, 0))

    return  typeString, nameString
end

M.getArgumentTableWithoutDefaults = function(functionNode)
    local argumentTable = {}

    local query = localQueries.parameterDeclarationQuery

    local matches = query:iter_matches(functionNode, 0)
    for id, match, metadata in matches do 
        local typeNode = match[1]
        local idNode = match[2]

        local typeText = vim.treesitter.get_node_text(typeNode,0)
        local idText = vim.treesitter.get_node_text(idNode,0)
        table.insert(argumentTable,{typeText,idText})
    end
    return {M.getTableLength(argumentTable),argumentTable}
end

M.snakeCaseHunting = function()
    local query = localQueries.snakeCaseVariableQuery
    local iterCaptures = query:iter_captures(vim.treesitter.get_node():root(),0)
    local snakeLines = {}
    for id, node, metadata, match in iterCaptures do
        --don't complain about include guards
        if not node:parent():type() == "preproc_def" and not node:parent():type() == "preproc_ifdef" then
            local nodeStartingRow, nodeStartingCol = node:start() -- TS is zero-indexed, neovim lines are 1-indexed
            table.insert(snakeLines,{nodeStartingRow+1,nodeStartingCol})
        end
    end
    return snakeLines
end

M.findPureVirtualNodes = function()
    local query = localQueries.pureVirtualFunctionQuery
    local iterCaptures = query:iter_captures(vim.treesitter.get_node():root(),0)
    local tableOfNodes = {}
    for id, node, metadata, match in iterCaptures do
        --add logic
    end
end

--[[
pass in a class_specifier node, and find all non-pure-virtual members, templates, constructors, etc
]]--
M.getImplementableFields = function(classNode)
    local query = localQueries.findNonPureVirtualMembers

    local nodeFlavor = nil
    local tableOfNodes = {}


    local matches = query:iter_matches(classNode, 0)
    for id, match, metadata in matches do 
        local isStatic = match[1]
        local typeNode = match[2]
        local functionDeclarator = match[3]
        local pointerDeclarator = match[4]
        local referenceDelcarator = match[5]
        local functionDeclaration = match[6]
        local templateOrConstructorDeclaration = match[7]
        if typeNode then
            vim.notify(getNodeText(typeNode))
        end
    end
    -- end

end

return M
