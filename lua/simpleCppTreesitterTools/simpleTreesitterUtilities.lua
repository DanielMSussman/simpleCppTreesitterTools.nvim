local localQueries = require("simpleCppTreesitterTools.customTreesitterQueries")

local M= {}

--get the text of a node, defaulting to using the current buffer as the source of text
local getNodeText = function(n,bufferNumberOrString)
    return vim.treesitter.get_node_text(n,bufferNumberOrString or 0)
end

--climb up the syntax tree until you find a node of type nodeType
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

--[[
use a custom query to find all virtual functions in the header
Return a table. Each entry is (a) a string you can use in the derived class
and (b) a boolean. True indicates that the function is pure virtual.
]]--
M.findVirtualNodes = function(classNode)
    local query = localQueries.virtualFunctionQuery
    local iterCaptures = query:iter_matches(classNode,0)

    local tableOfNodes = {}
    local matches = query:iter_matches(classNode, 0)
    for id, match, metadata in iterCaptures do
        local virtual = match[1]
        local type = match[2]
        local declarator = match[3]
        local isPureVirtual = match[4]
        local copyString = getNodeText(virtual).." "..getNodeText(type).." "..getNodeText(declarator)..";"
        --try not to be blinded by the following string manipulation, in which I put the reference and pointer symbols where I want them. You should probably just use a formatter 
        copyString = copyString:gsub("%s&", "&")
        copyString = copyString:gsub("%s%*", "%*")
        copyString = copyString:gsub("&", " &")
        copyString = copyString:gsub("%*", " %*")
        copyString = copyString:gsub("%s+", " ")
        copyString = copyString:gsub("&%s", "&")
        copyString = copyString:gsub("%*%s", "%*")
        if isPureVirtual then
            table.insert(tableOfNodes,{"        "..copyString,true})
        else
            table.insert(tableOfNodes,{"        "..copyString,false})
        end
    end
    return tableOfNodes
end

--[[
Create a table containing the row and column of all variables (or function arguments)
that have a name_in_snake_case.
This is basically just to demonstrate simple queries that use not only
captures but also predicates.
]]--
M.snakeCaseHunting = function()
    local query = localQueries.snakeCaseVariableQuery
    local iterCaptures = query:iter_captures(vim.treesitter.get_node():root(),0)
    local snakeLines = {}
    for id, node, metadata, match in iterCaptures do
        --don't complain about include guards
        if node:parent():type() ~= "preproc_def" and node:parent():type() ~= "preproc_ifdef" then
            local nodeStartingRow, nodeStartingCol = node:start() -- TS is zero-indexed, neovim lines are 1-indexed
            table.insert(snakeLines,{nodeStartingRow+1,nodeStartingCol})
        end
    end
    return snakeLines
end

--[[
A low-effort "best-effort" test to see if a function has already been implemented
in the cpp file. This works by reading the cpp file in as a string and then using
treesitter to parse that string. We run a custom query to get information about the 
function definitions in the cpp file, and try our best to match things up.
Right now a "match" includes having the same function name and the same list of 
types for all arguments (i.e., changing the variable names shouldn't matter)..
If there is a match, we also return the line number that we find the match on.
]]--
M.testImplementationFileForFunction = function(functionName,listOfParameterTypes,fileName)
    --read in the file, and run the query on a stringified version of it
    local fileContent = vim.fn.readfile(fileName)
    local functionNodeStart = nil
    if not fileContent then
        return nil,functionNodeStart
    end

    local fileString = table.concat(fileContent,"\n")
    local parser = vim.treesitter.get_string_parser(fileString,"cpp")
    local tree = parser:parse()
    local rootNode = tree[1]:root()

    local query = localQueries.implementationFileQueryForFunctions
    local matches = query:iter_matches(rootNode, fileString)

    local parameterStrings = {}
    local typeStrings={}
    for id, match, metadata in matches do 
        --matches have nodes like:
        --type? functionName, qualifiedID, parameterList,functionDecl,funcDefinition
        fileFunctionName = getNodeText(match[2],fileString)
        --what line does this function start on? Are there template declarations above it?
        functionNodeStart = match[2]:start()
        while string.find(fileContent[functionNodeStart],"template") do 
            functionNodeStart = functionNodeStart - 1
        end
        --if we find a function of the same name, does it have the same set of argument types?
        if fileFunctionName == functionName then
            local parameterStrings, typeStrings = M.parseParameterList(match[4],fileString)
            if table.concat(listOfParameterTypes) == table.concat(typeStrings) then
                return true, functionNodeStart
            end
        end
        
    end
    return false, functionNodeStart
end

--[[
given a parameter_list node, cycle through the children. 
Grabbing any constness, the parameter type, and the identifier.
]]--
M.parseParameterList = function(parameterListNode,bufferNumberOrString)
    local query = localQueries.parameterListParsingQuery
    local matches = query:iter_matches(parameterListNode, bufferNumberOrString or 0)

    local parameterStrings = {}
    local typeStrings={}
    for id, match, metadata in matches do 
        local parameterDeclarationString=getNodeText(match[2],bufferNumberOrString or 0).." "..getNodeText(match[3],bufferNumberOrString or 0)

        if match[1] then
            parameterDeclarationString = getNodeText(match[1],bufferNumberOrString or 0).." "..parameterDeclarationString
        end
        table.insert(parameterStrings,parameterDeclarationString)
        table.insert(typeStrings,getNodeText(match[2],bufferNumberOrString or 0))
    end

    return parameterStrings, typeStrings

end

--[[
Iterate through children of a function_declarator.
Return the identifier, and the parameter_list. Check the type_qualifier
(i.e., is the function const)
]]--
M.decomposeFunctionDeclarator = function(functionDeclaratorNode)
    local functionName,parameterListNode,typeQualifier = nil,nil,nil
    for i = 0, functionDeclaratorNode:child_count() - 1 do
        local child = functionDeclaratorNode:child(i)

        if child:type() == "type_qualifier" then
            typeQualifier = "const"
        end

        if child:type() == "identifier" or child:type() == "field_identifier" or child:type() == "destructor_name" then
            functionName = getNodeText(child)
        end
        if child:type() == "parameter_list" then
            parameterListNode = child
        end
    end

    return functionName,parameterListNode,typeQualifier
end

--[[
 search upward for template declarations, then query for the template parameter list
]]--
M.findParentTemplates = function(functionNode)
    local templateString = nil
    local templateAncestor = M.getNamedAncestor(functionNode,"template_declaration")
    if templateAncestor then
        local query = localQueries.templateParameterQuery
        for id, match, metadata in query:iter_matches(templateAncestor,0) do
            templateString = getNodeText(match[1])
        end
    end
    if templateString then
        templateString = "template"..templateString
    end
    return templateString
end

--[[
We handle class templates slightly differently, since they imply 
that we'll need to do stuff like 
    className<T>::functionName(...)
]]--
M.getClassTemplateInformation = function(classNodeTemplateDeclaration)
    local classTemplateString = nil
    local classAngleBrackets = {}
    local query = localQueries.classTemplateParameterQuery
    for id, node, metadata, match in query:iter_captures(classNodeTemplateDeclaration, 0) do
        local name = query.captures[id]
        if name == "typeIdentifier" then
            table.insert(classAngleBrackets,getNodeText(node))
        end
        if name == "templateParameterList" then
            classTemplateString = getNodeText(node)
        end
    end
    if not classTemplateString then
        return nil,nil
    end

    return "template"..classTemplateString,"<"..table.concat(classAngleBrackets,",")..">"
end

--given a list of strings forming the parameter list, appropriately concatenate
M.combineParameterListStrings = function(parameterListStrings)
    if #parameterListStrings ==0 then
        return "()"
    else
        return "("..table.concat(parameterListStrings,", ")..")"
    end
end

--[[
Starting from a class_specifier node, search for all non-pure-virtual member functions,
all templated functions, constructors, etc.
Returns a table, where each entry contains a function node and a bunch of string 
information that we'll use for writing our files.
]]--
M.getImplementableFields = function(classNode)

    local tableOfNodes = {} -- this is what we'll be returning...

    local query = localQueries.findNonPureVirtualMembers
    local matches = query:iter_matches(classNode, 0)
    for id, match, metadata in matches do 
        --[[
        look at this mess of variables! I'm trying to make it extremely explicit
        what we're looking for and where in the corresponding query match they will be.
        The order in the match table corresponds to the order in which the capture groups appear
        ]]--
        local functionName = nil
        local returnTypeString = nil
        local templateString = nil
        local parameterListStrings = nil
        local listOfParameterTypes = nil --for testing if the declaration exists in the cpp file, even if the variables have different names
        local nodeLineNumber = nil
        local preTypeKewordString = nil
        local postTypeKewordString = nil
        local functionTypeString = nil

        -- gt local variables corresponding to the match capture groups
        local isConstexpr = match[1]
        local isStatic = match[2]
        local typeNode = match[3]
        local functionDeclarator = match[4]
        local pointerDeclarator = match[5]
        local referenceDeclarator = match[6]
        local functionDeclaration = match[7]
        local templateOrConstructorDeclaration = match[8]

        --get the function node, and determine if it returns a pointer or a reference
        local functionNode
        if functionDeclarator then
            functionNode = functionDeclarator
        elseif pointerDeclarator then
            functionNode = pointerDeclarator:child(1)
            functionTypeString = "*"
        elseif referenceDeclarator then
            functionNode = referenceDeclarator:child(1)
            functionTypeString = "&"
        end
        --parse the return type
        if typeNode then
            returnTypeString = getNodeText(typeNode)
            if functionTypeString then
                returnTypeString = returnTypeString..functionTypeString
            end
            if isConstexpr then
                returnTypeString = "constexpr "..returnTypeString
            end
        end

        -- get the function name, the node for its list of parameters, function constness, and the line number of the function
        if functionNode then
            functionName,parameterListNode,postTypeKewordString = M.decomposeFunctionDeclarator(functionNode)
            nodeLineNumber = functionNode:start()+1
        end

        --parse the parameter list, handling consts and default argments
        if parameterListNode then
            parameterListStrings, listOfParameterTypes=M.parseParameterList(parameterListNode)
        end

        --if we have a template function, or a class which is a template, get the template string 
        if templateOrConstructorDeclaration then
            templateString = M.findParentTemplates(functionNode)
        end

        if not returnTypeString then
            returnTypeString = false
        end
        if not postTypeKewordString then
            postTypeKewordString = false
        end
        if not templateString then
            templateString = false
        end
        local nodeBatch = {functionNode,returnTypeString,functionName,M.combineParameterListStrings(parameterListStrings),listOfParameterTypes,postTypeKewordString,templateString,nodeLineNumber}
        table.insert(tableOfNodes,nodeBatch)
    end
    return tableOfNodes 
end

return M
