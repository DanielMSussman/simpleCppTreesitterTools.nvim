local M = {}

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
