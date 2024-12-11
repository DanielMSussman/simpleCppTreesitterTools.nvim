local M = {}

--[[
query for member function template parameters
]]--
M.templateParameterQuery = vim.treesitter.query.parse(
    "cpp",
    [[
      (template_declaration
      (template_parameter_list)@templateParameterList) @functionTemplate
    ]]
)

--[[
query for template parameters on a class
]]--
M.classTemplateParameterQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    (template_declaration
      (template_parameter_list
        (type_parameter_declaration
          (type_identifier ) @typeIdentifier ) @templateParameterDelcaration)* @templateParameterList
      (class_specifier)) @classTemplate
    ]]
)

--[[
query for either field declarations (standard functions) or 
declarations (templates, constructors, etc), but use known 
structure to ignore anything that is a pure virtual function
 Since we're looking for "declarations", and not "definitions", this won't capture members defined in the header
]]--
M.findNonPureVirtualMembers = vim.treesitter.query.parse(
    "cpp",
    [[
    ;; square brackets indicate alternatives... we're looking *either* for a field_declaration (with a bunch of specific children) *or* a declaration (with a bunch of specific children. 
    ;; "field_declarations" are functions, "declarations" are either templates or things like constructors
    [
     (field_declaration
       ;; (node_type)* lets us succeed on zero matches
       (type_qualifier)* @constexprKeyword
       (storage_class_specifier)* @staticKeyword
       ;;(_) is a wildcard node (primitive_type, qualified_identifier, etc)
       type: (_) @type 
       declarator :
       [
        (function_declarator) @valueReturn
        (pointer_declarator) @pointerReturn
        (reference_declarator) @referenceReturn
        ] 
       !default_value ;; reject functions with a default_value ("virtual void foo() = 0;")
       ) @functionDeclaration
     (declaration
       (type_qualifier)* @constexprKeyword
       (storage_class_specifier)* @staticKeyword
       type: (_)* @type ;;class constructor won't have a type
       [
        (function_declarator) @valueReturn
        (pointer_declarator) @pointerReturn
        (reference_declarator) @referenceReturn
        ]
       ) @templateOrConstructorDeclaration
     ]
    ]]
    )

--[[
what do functions look like in the implementation file? Use this to help test if a function has already been implemented
]]--
M.implementationFileQueryForFunctions = vim.treesitter.query.parse(
    "cpp",
    [[
    (function_definition
      type: (_)? @type
      (function_declarator
        (
        (qualified_identifier
          [
           (identifier) @functionName
           (destructor_name) @functionName
           ]) @qualifiedID
        (parameter_list) @parameterList
                )
        ) @funcDecl
        )@funcDefinition
    ]]
)

--[[
work through a parameter_list, optionally grabbing constness and definitely getting types and names 
]]--
M.parameterListParsingQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    [
     (parameter_declaration
        (
        (type_qualifier)? @typeQualifier ;; (_)? means the node is optional.
        type: (_) @typeId
        declarator: (_) @variableName
            )
        )@paramDecl
     (optional_parameter_declaration
        (
        (type_qualifier)? @typeQualifier
        type: (_) @typeId
        declarator: (_) @variableName
            )
        )@paramDecl
    ]
    ]]
)

--[[
Find pure virtual functions, which will be a node that has a type,
and then a function_declarator and a number_literal as siblings
(because of the "virtual type functionName(...) = 0; syntax)
]]--
M.pureVirtualFunctionQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    (field_declaration
        ["virtual"] @virt
        type : (_) @type
        declarator : (_) @decl
        (number_literal)
        ) @pureVirtualFunction
    ]]
)

--[[
One can filter capture groups by their properties.
For instance, #eq? can be used to test if a captured node is equal to some identifier.
This can be used to test for equality with particular strings, with other capture groups, etc.
As a ridiculous example, we'll use #match? (very similar, but with regexes) to go hunting for snake_case variables. 
Because we're doing this with nodes, this won't return snake_case words in general (e.g., in a comment).
]]--
M.snakeCaseVariableQuery = vim.treesitter.query.parse(
    "cpp",
    [[
    [
    ((identifier) @snakeCase
        (#match? @snakeCase "[a-zA-Z]+(_[a-zA-Z]+)"))
    ((field_identifier) @snakeCase
        (#match? @snakeCase "[a-zA-Z]+(_[a-zA-Z]+)"))
    ]
    ]]
)
return M
