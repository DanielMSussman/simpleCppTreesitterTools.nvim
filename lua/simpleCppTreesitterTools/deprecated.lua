-- once we identify a function / constructor / whatever, what string should we build up to add to the cpp file?
M.buildImplementationStringFromNode = function(node, nodeTypeLabel,className)
    -- the implementation string we want to add to the cpp file clearly depends on the node type. Let's handle that logic and build up some strings
    if nodeTypeLabel == "constructorLike" then
        local functionText = vim.treesitter.get_node_text(node,0)
        return string.format("%s::%s",className,functionText)
    end
    if nodeTypeLabel == "templatedFunction" then
    end
    if nodeTypeLabel == "standardFunction" then
        local primitiveTypeText = vim.treesitter.get_node_text(node[2],0)
        local functionDeclarationText = vim.treesitter.get_node_text(node[1],0)
        local classAndFunction = string.format("%s::%s",className,functionDeclarationText)
        return string.format("%s %s",primitiveTypeText,classAndFunction)
    end

end

M.searchTableForString = function(list,element)
    for i, line in ipairs(list) do 
        if string.find(line,element) then
            vim.notify("AA "..element.."   "..line.."   "..tostring(i))
            return i 
        end
    end
end

--returns true or false. Also returns the range corresponding to the parent of the node. Note that files are 1 indexed and ranges are 0 indexed
M.functionDeclarationExistsInFile = function(functionDeclarationToTest)
    -- Read the file content, concatenate into a single string, and parse it
    local fileContent = vim.fn.readfile(M.data.implementationFile)
    local fileString = table.concat(fileContent,"\n")

    local startLine = M.searchTableForString(fileContent,functionDeclarationToTest)
    if startLine then
        vim.notify(functionDeclarationToTest.."  "..tostring(startLine))
    end

    local startEndLine = nil

    local parser = vim.treesitter.get_string_parser(fileString,"cpp")
    local tree = parser:parse()
    local rootNode = tree[1]:root()
    --define a query for function_declarators
    -- local query = vim.treesitter.query.parse(
    --     "cpp",
    --     [[
    --   (declaration 
    --     (init_declarator 
    --       (function_declarator) @function_declarator))
    -- ]]
    -- )
    local query = vim.treesitter.query.parse(
        "cpp",
        [[
      (function_definition 
          (function_declarator) @function_declarator)
    ]]
    )
    -- Run the query on the parsed tree, and iterate over all matches
    local matches = query:iter_matches(rootNode:root(), fileString)
    for _, match in matches do
        for id, node in pairs(match) do
            if id == 1 then -- Check if it's the function_declarator node
                local functionDeclaration = vim.treesitter.get_node_text(node, fileString)
                if functionDeclaration == functionDeclarationToTest then
                    -- vim.notify(functionDeclaration)
                    local range = vim.treesitter.get_range(node:parent(),fileString)
                    startEndLine = {range[1],range[4]}
                    -- vim.notify(vim.inspect(range))
                    -- vim.notify(vim.inspect(startEndLine))
                    return true , startEndLine
                end
            end
        end
    end

    return false , startEndLine
end



M.conditionallyConstructSignature = function(contentToAppend,signature,classAndFunction, verboseNotifications) 
    local contentHolder = contentToAppend
    if M.functionDeclarationExistsInFile(classAndFunction) then
        if(verboseNotifications) then
            vim.notify("implementation for "..classAndFunction.." already written")
        end
    else
        if(verboseNotifications) then
            vim.notify("adding "..classAndFunction.." to cpp file")
        end
        M.appendFormatedSignatureToTable(contentHolder,signature)
    end
    return contentHolder
end
-- from the class node, query for constructors and destructors
M.queryForConstructorsAndDestructors = function(className, classNode,contentToAppend,verboseNotifications)

    local contentHolder = contentToAppend
    local classQuery = vim.treesitter.query.parse(
        "cpp",
        [[
        (declaration
          (function_declarator) @function_declarator)
      ]]
    )

    local constructorMatches = classQuery:iter_matches(classNode:root(), 0)
    for _, match in constructorMatches do 
        local functionNode = match[1]
        local implementationString = M.buildImplementationStringFromNode(functionNode,"constructorLike",className)

        contentHolder = M.conditionallyConstructSignature(contentHolder,implementationString,implementationString,verboseNotifications)
    end
    return contentHolder
end

-- query for templated functions 
M.queryForTemplatedFunctions = function(className, classNode,contentToAppend,verboseNotifications)
    local contentHolder = contentToAppend
-- TODO
    return contentHolder
end
-- query for normal functions 
M.queryForFunctions = function(className, classNode,contentToAppend,verboseNotifications)
    local contentHolder = contentToAppend

    -- from the class node, query for pairs of types and function declarations
    --  By starting with field_declaration, we filter out cases where the
    --  implementation is in the header itself
    local query = vim.treesitter.query.parse(
        "cpp",
        [[
        (field_declaration
          (primitive_type) @primitive_type
          (function_declarator) @function_declarator)
      ]]
    )

    local matches = query:iter_matches(classNode:root(), 0)
    for _, match in matches do 
        local primitiveNode = match[1]
        local functionNode = match[2]

        local implementationString = M.buildImplementationStringFromNode({functionNode,primitiveNode},"standardFunction",className)

        -- local range = vim.treesitter.get_range(functionNode,0)
        -- local startEndLine = {range[1],range[4]}
        -- vim.notify(vim.inspect(range))
        -- vim.notify(vim.inspect(startEndLine))

        local primitiveTypeText = vim.treesitter.get_node_text(primitiveNode,0)
        local functionDeclarationText = vim.treesitter.get_node_text(functionNode,0)
        local classAndFunction = string.format("%s::%s",className,functionDeclarationText)
        -- local signature = string.format("%s %s",primitiveTypeText,classAndFunction)
        contentHolder = M.conditionallyConstructSignature(contentHolder,implementationString,classAndFunction,verboseNotifications)
    end
    return contentHolder
end

