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
M.getTableLength =function(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
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
M.appendFormatedSignatureToTable = function(contentToAppend,signature)
    table.insert(contentToAppend,"")
    for i, line in ipairs(signature) do 
        table.insert(contentToAppend, line)
    end
    table.insert(contentToAppend, "    {")
    table.insert(contentToAppend, "    }")
end

M.writeNodeToFile = function(node,nodeFlavor,className)
    local implementationString = M.constructImplementationStringFromNode(node,nodeFlavor,className)
    local implementationStub = {}
    M.appendFormatedSignatureToTable(implementationStub,implementationString)
    local implementationExistsOnLineNumber = M.testForImplementationInFile(implementationString)

    -- print(vim.inspect(implementationStub))

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

--[[
This query looks for constructor/destructors, standard functions, and templated functions
The idea: inside the class is the field_declaration_list, so look for the standard treesitter nested patterns
]]--
M.constructorFunctionTemplateQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    (field_declaration_list
        [
            (declaration 
                (function_declarator)) @classDecl
            (field_declaration
                (function_declarator)) @funcDecl
            (template_declaration) @templateDecl
        ])
    ]]
)

--[[
This query looks for constructor/destructors, standard functions, and templated functions
The idea: inside the class is the field_declaration_list, so look for the standard treesitter nested patterns
]]--
M.testForFieldIdentifier = vim.treesitter.query.parse(
    "cpp",
    [[
    (field_declaration
        (field_identifier) @fieldId)
    ]]
)


--[[
For a query on a templated function. 
Capture nodes for the template list as well as everything above
]]--
M.templateDeclarationFunctionNameQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    (template_declaration
    (
        (template_parameter_list) @templateList 
        (declaration
            (
                [
                    (primitive_type) @primitiveType 
                    (type_identifier) @typeIdentifier 
                ]
                [
                    (function_declarator
                        (identifier) @functionName)
                    (reference_declarator (function_declarator
                        (identifier) @refernceFunction))
                    (pointer_declarator (function_declarator
                        (identifier) @pointerFunction))
                ]
            )
        )
        ))
    ]]
)
M.constructorLikeNameQuery = vim.treesitter.query.parse(
    "cpp",
    [[
        [
            (declaration
                (function_declarator 
                    (identifier) @classConstructorIdentifier)@classConstructorDecl)
            (declaration
                (function_declarator 
                    (destructor_name) @classDestructorName))
        ]
    ]]
)
--[[
For a standard member function (not templated, not a constructor-like item)
this query checks whether it matches the pattern for being a 
standard type, a reference, or a pointer 
]]--
M.fieldDeclarationFunctionNameQuery = vim.treesitter.query.parse(
    "cpp",
    [[
(field_declaration
  (
   [
    (primitive_type) @primitiveType 
    (type_identifier) @typeIdentifier 
    (qualified_identifier) @qualifiedType 
        ]
  [
   (function_declarator
     (field_identifier) @functionName)
   (reference_declarator (function_declarator
     (field_identifier) @referenceFunction))
   (pointer_declarator (function_declarator
     (field_identifier) @pointerFunction))
    ]))
    ]]
)
--
--[[
this query handles both optional and required parameter declarations and both 
primitive types and type_ids (for templated functions)
The idea: from the node, look for a child which is a parameter_list, which itself
has either parameter_declaration or optional_parameter_declaration children 
(arguments and arguments with default values respectively). For each parameter
declaration, get either the primitive type or (in the case of template<typename T>
like constructions) the type identifier
]]--
M.parameterDeclarationQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    (parameter_list
      [
       (optional_parameter_declaration
         [
          (primitive_type) @type
          (type_identifier) @type
          (qualified_identifier) @type
          ]
         [
         (identifier) @id
         (reference_declarator) @id
         (pointer_declarator) @id
        ])
       (parameter_declaration
         [
          (primitive_type) @type
          (type_identifier) @type
          (qualified_identifier) @type
          ]
         [
         (identifier) @id
         (reference_declarator) @id
         (pointer_declarator) @id
        ])
       ]
      )
    ]]
    )


--[[
Just finds the word "virtual"... use it, go to the end of the node, look at the rest of the line, etc
]]--
M.virtualKeywordQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    [
    "virtual"
    ] @virtualSpecifier
    ]]
)
