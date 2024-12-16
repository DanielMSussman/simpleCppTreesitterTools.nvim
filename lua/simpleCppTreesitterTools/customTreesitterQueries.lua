local M = {}
--[[
Custom queries have been written in the corresponding *.scm files in the /queries/cpp/ director of this plugin.

I wanted to emphasize, though, that you can write these random one-ff queries whenever you want (to include them in snippets, etc).
So, each query here has a comment block above it describing what's going on, a line that defines the query by using the query.get("language", "fileNameOfQuery") syntax, and then a block of commented-out lines that shows how you would do exactly the same thing not in the .scm file but using the query.parse(...) syntax.

Also, the actual queries used in this plugin are almost certainly not the best (or most elegant)
possible query for the job.
In part, I wanted to write progressively more complicated samples
so that you can see how to build them up, and in part I'm just not that smart.

Hope this is helpful!
]]--



--[[
Query for member function template parameters.
This will look for any template_declaration node which has a template_parameter_list as a child,
and assign both of those nodes to a capture group (denoted by the @captureGroupName).
That means that when iterating over matches that this query finds,
we'll be able to easily grab the nodes that we specify.

To emphasize: the query.get(...) syntax means that you can find the contents of this query in the 
/queries/cpp/templateParameterQuery.scm file.
]]--
M.templateParameterQuery = vim.treesitter.query.get("cpp","templateParameterQuery")
-- M.templateParameterQuery = vim.treesitter.query.parse("cpp",
--     [[
--       (template_declaration
--       (template_parameter_list) @templateParameterList
--           ) @functionTemplate
--     ]]
-- )

--[[
A slightly longer query for template parameters associated with a class
You can see (a) that you can nest arbitrarily many children, capturing
as many of the nodes as you want, and (b) that you can match on sibling nodes:
here we'll only pick up template_declarations that have both a template_parameter_list
*and* a class_specifier as children (hence: we'll only get templated classes, and not
templated member functions).

This also introduces the (nodeType)* syntax, which means it will match on any number of sibling
nodeTypes (including on the presence of zero of them)
]]--
M.classTemplateParameterQuery = vim.treesitter.query.get("cpp","classTemplateParameterQuery")
-- M.classTemplateParameterQuery = vim.treesitter.query.parse("cpp",
--     [[
--     (template_declaration
--       (template_parameter_list
--         (type_parameter_declaration
--           (type_identifier ) @typeIdentifier ) @templateParameterDelcaration)* @templateParameterList
--       (class_specifier)) @classTemplate
--     ]]
-- )

--[[
This next one I'm including just to show how you can filter capture groups
by their properties. For instance, #eq? can be used to test if a captured 
node is equal to some identifier. This can be used to test for equality with 
particular strings, with other capture groups, etc. As a ridiculous example,
we'll use #match? (very similar to #eq?, but with regexes) to go hunting for
snake_case variables. Because we're doing this with nodes, this won't return 
snake_case words in general (e.g., in a comment).

This example also introduces the [ (nodeType1) (nodeType2) ] idea: it will match on
either a snakeCase "identifer" node or a "field_identifier" node.
We're about to use these "alternates" pattern a lot.
]]--
M.snakeCaseVariableQuery = vim.treesitter.query.get("cpp","snakeCaseVariableQuery")
-- M.snakeCaseVariableQuery = vim.treesitter.query.parse("cpp",
--     [[
--     [
--     ((identifier) @snakeCase
--         (#match? @snakeCase "[a-zA-Z]+(_[a-zA-Z]+)"))
--     ((field_identifier) @snakeCase
--         (#match? @snakeCase "[a-zA-Z]+(_[a-zA-Z]+)"))
--     ]
--     ]]
-- )

--[[
This query will find virtual functions in the header.

First, we see that we can search for specific words, and capture them:
this will only find a field_declaration that has "virtual" in part of it.

Next, we see that we can ask for nodes that have specific field names ("type", "declarator", etc).

Next, we have wildcard nodes: (_). These will match on anything, so, e.g., the
"type : (_) @type"
line will make a capture group that can get a primitive_type (voids, ints, etc), or a type_identifier (T corresponding to a template<typename T>, or a qualified_identifier (e.g., a custom data type you've defined) node.

Finally, we can have optional nodes, marked like (nodeType)?. The query will match with or without finding these, but if it is found
we can put it in a capture group.
Here I'm using that to detect whether a function is pure virtual or not.
(based on the "virtual type functionName(...) = 0; syntax)
]]--
M.virtualFunctionQuery = vim.treesitter.query.get("cpp","virtualFunctionQuery")
-- M.virtualFunctionQuery = vim.treesitter.query.parse("cpp",
--     [[
--     (field_declaration
--         ["virtual"] @virt
--         type : (_) @type
--         declarator : (_) @decl
--         (number_literal)? @pureVirtual
--         ) @virtualFunction
--     ]]
-- )

--[[
This workhorse query of the plugin finds all functions, templates, constructors, etc, that aren't pure virtual functions
(and, hence, should be implemented in the cpp file).

It uses everything above (note that there are times when I'm using the (_)* where I could have just as well used the (_)? idea).
Note that since we're looking for "declarations", and not "definitions", this
will automatically skip over functions that are defined in the header itself.
]]--
M.findNonPureVirtualMembers = vim.treesitter.query.get("cpp","findNonPureVirtualMembers")
-- M.findNonPureVirtualMembers = vim.treesitter.query.parse("cpp",
--     [[
--     ;;look for either field_declarations or declarations slightly different child node patterns and capture groups
--     [
--      ;; "field_declarations" are functions
--      (field_declaration
--        ;; (node_type)* lets us succeed on zero matches
--        (type_qualifier)* @constexprKeyword
--        (storage_class_specifier)* @staticKeyword
--        ;;(_) is a wildcard node (primitive_type, qualified_identifier, etc)
--        type: (_) @type 
--        declarator :
--        [
--         ;; since I want to be able to add the correct * or & or nothing, explicitly list out the possible declarators
--         (function_declarator) @valueReturn
--         (pointer_declarator) @pointerReturn
--         (reference_declarator) @referenceReturn
--         ] 
--        !default_value ;; reject functions with a default_value ("virtual void foo() = 0;")
--        ) @functionDeclaration
--      ;;"declarations" are either templates or things like constructors
--      (declaration
--        (type_qualifier)* @constexprKeyword
--        (storage_class_specifier)* @staticKeyword
--        type: (_)* @type ;;class constructor won't have a type, so we need to be able to match on zero or more types
--        [
--         (function_declarator) @valueReturn
--         (pointer_declarator) @pointerReturn
--         (reference_declarator) @referenceReturn
--         ]
--        ) @templateOrConstructorDeclaration
--      ]
--     ]]
--     )


--[[
A query that is meant to be applied to a parameter_list, and grab 
nodes corresponding to constness, the type, and the argument names.
For optional_parameter_declarations --- things like the second argument in 
    void foo(int a, int b=12);
get all of the same information. We won't need the default argument when we put stuff in the implementation file.
]]--
M.parameterListParsingQuery = vim.treesitter.query.get("cpp","parameterListParsingQuery")
-- M.parameterListParsingQuery = vim.treesitter.query.parse("cpp",
--     [[
--     [
--      (parameter_declaration
--         (
--         (type_qualifier)? @typeQualifier
--         type: (_) @typeId
--         declarator: (_) @variableName
--             )
--         )@paramDecl
--      (optional_parameter_declaration
--         (
--         (type_qualifier)? @typeQualifier
--         type: (_) @typeId
--         declarator: (_) @variableName
--             )
--         )@paramDecl
--     ]
--     ]]
-- )

--[[
Finally, a query to the implementation file for information about the functions defined there.
This highlights something I haven't quite figured out: how to artfully design queries where the nesting pattern might be different. For now, 
I'll just kludge along, with explicit patterns for 
value, pointer, and reference returns.

]]--
M.implementationFileQueryForFunctions = vim.treesitter.query.get("cpp","implementationFileQueryForFunctions")
-- M.implementationFileQueryForFunctions = vim.treesitter.query.parse("cpp",
--     [[
--     (function_definition
--       type: (_)? @type
--       [
--       (function_declarator
--         (
--         (qualified_identifier
--           [
--            (identifier) @functionName
--            (destructor_name) @functionName
--            ]) @qualifiedID
--         (parameter_list) @parameterList
--                 )
--         ) @funcDecl
--         (pointer_declarator
--       (function_declarator
--         (
--         (qualified_identifier
--           [
--            (identifier) @functionName
--            (destructor_name) @functionName
--            ]) @qualifiedID
--         (parameter_list) @parameterList
--                 )
--                 )) @funcDecl
--         (reference_declarator
--       (function_declarator
--         (
--         (qualified_identifier
--           [
--            (identifier) @functionName
--            (destructor_name) @functionName
--            ]) @qualifiedID
--         (parameter_list) @parameterList
--                 )
--                 )) @funcDecl
--     ]
--         )@funcDefinition
--     ]]
-- )
return M
