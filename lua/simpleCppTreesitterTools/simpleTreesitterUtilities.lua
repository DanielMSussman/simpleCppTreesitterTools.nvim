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
    for pattern, match, metadata in iterCaptures do
        -- local virtual = match[1]
        -- local type = match[2]
        -- local declarator = match[3]
        -- local isPureVirtual = match[4]

        local virtual, type,declarator, isPureVirtual = nil


        for id, nodes in pairs(match) do
            local name  = query.captures[id]
            for _,node in ipairs(nodes) do
                if name == "virt" then
                    virtual =node
                end
                if name == "type" then
                    type =node
                end
                if name == "decl" then
                    declarator =node
                end
                if name == "pureVirtual" then
                    isPureVirtual =node
                end
            end
        end



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
M.testImplementationFileForFunction = function(functionName,listOfParameterTypes,className,fileName)
    --read in the file, and run the query on a stringified version of it
    if vim.fn.filereadable(fileName) == 0 then
        return nil,nil
    end
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
    for pattern, match, metadata in matches do 
        --matches have nodes like:
        --type? functionName, qualifiedID, parameterList,functionDecl,funcDefinition
        
        for id, nodes in pairs(match) do
            local name  = query.captures[id]
            for _,node in ipairs(nodes) do
                if name == "qualifiedID" then
                    qualifiedIDName = getNodeText(node,fileString)
                end
            end
        end
        --get the class name by looking at the qualified_identifier and stripping away the double colons and everything after them
        local classSpecifier = qualifiedIDName:match("^(.*)::")
        local functionNode = nil
        if classSpecifier == className then
            --if we have the right class name, is there a function of the same name with the same set of argument types?
            local parameterStrings, typeStrings = nil
            for id, nodes in pairs(match) do
                local name  = query.captures[id]
                for _,node in ipairs(nodes) do
                    if name == "functionName" then
                        functionNode = node
                        fileFunctionName = getNodeText(functionNode,fileString)
                    end
                    if name == "parameterList" then
                        parameterStrings,typeStrings = M.parseParameterList(node,fileString)
                    end
                end
            end

            if fileFunctionName == functionName and
                table.concat(listOfParameterTypes) == table.concat(typeStrings) then
                --what line does this function start on? Are there template declarations above it?
                functionNodeStart = functionNode:start()
                while string.find(fileContent[functionNodeStart],"template") do 
                    functionNodeStart = functionNodeStart - 1
                end
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
    for pattern, match, metadata in matches do 

        local typeQual,typeIdText, varName = nil
        for id, nodes in pairs(match) do
            local name  = query.captures[id]
            for _,node in ipairs(nodes) do
                if name == "typeQualifier" then
                    typeQual = getNodeText(node, bufferNumberOrString or 0)
                end
                if name == "typeId" then
                    typeIdText = getNodeText(node,bufferNumberOrString or 0)
                end
                if name == "variableName" then
                    varName = getNodeText(node, bufferNumberOrString or 0)
                end
            end
        end

        local parameterDeclarationString = typeIdText.." "..varName

        if typeQual then
            parameterDeclarationString = typeQual.." "..parameterDeclarationString
        end
        table.insert(parameterStrings,parameterDeclarationString)
        table.insert(typeStrings,typeIdText)
    end

    return parameterStrings, typeStrings

end

--[[
Iterate through children of a function_declarator.
Return the identifier, and the parameter_list. Check the type_qualifier
(i.e., is the function const)
]]--
M.decomposeFunctionDeclarator = function(functionDeclaratorNode)
    -- print(vim.inspect(functionDeclaratorNode))
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
        for pattern, match, metadata in query:iter_matches(templateAncestor,0) do

            for id, nodes in pairs(match) do
                local name  = query.captures[id]
                for _,node in ipairs(nodes) do
                    if name == "templateParameterList" then
                        templateString = getNodeText(node)
                    end
                end
            end
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
    for pattern, match, metadata in matches do 
        --[[
        look at this mess of variables! 
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
        local isConstexpr, isStatic,typeNode,functionDeclarator,pointerDeclarator,referenceDeclarator,functionDeclarator templateOrConstructorDeclaration = nil


        for id, nodes in pairs(match) do
            local name  = query.captures[id]
            for _,node in ipairs(nodes) do
                if name == "constexprKeyword" then
                    isConstexpr =node
                end
                if name == "staticKeyword" then
                    isStatic =node
                end
                if name == "type" then
                    typeNode =node
                end
                if name == "valueReturn" then
                    functionDeclarator =node
                end
                if name == "pointerReturn" then
                    pointerDeclarator =node
                end
                if name == "referenceReturn" then
                    referenceDeclarator =node
                end
                if name == "functionDeclaration" then
                    functionDeclaration =node
                end
                if name == "templateOrConstructorDeclaration" then
                    templateOrConstructorDeclaration =node
                end
            end
        end

        --[[
        I'm trying to make it extremely explicit
        what we're looking for and where in the corresponding query match they will be.
        The order in the match table corresponds to the order in which the capture groups appear.
        You can confirm this by something like:
            for i,captures in ipairs(query.captures) do 
                vim.notify(tostring(i).." "..captures)
            end
        You can also, of course directly looking at the query.captures, a la:
            print(vim.inspect(query.captures))
        ]]--
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
