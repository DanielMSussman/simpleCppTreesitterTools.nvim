    ;;look for either field_declarations or declarations slightly different child node patterns and capture groups
    [
     ;; "field_declarations" are functions
     (field_declaration
       ;; (node_type)* lets us succeed on zero matches
       (type_qualifier)* @constexprKeyword
       (storage_class_specifier)* @staticKeyword
       ;;(_) is a wildcard node (primitive_type, qualified_identifier, etc)
       type: (_) @type 
       declarator :
       [
        ;; since I want to be able to add the correct * or & or nothing, explicitly list out the possible declarators
        (function_declarator) @valueReturn
        (pointer_declarator (function_declarator)) @pointerReturn ;;only grab pointer (or reference, below) return if a child is a function declaration
        (reference_declarator (function_declarator)) @referenceReturn
        ] 
       !default_value ;; reject functions with a default_value ("virtual void foo() = 0;")
       ) @functionDeclaration
     ;;"declarations" are either templates or things like constructors
     (declaration
       (type_qualifier)* @constexprKeyword
       (storage_class_specifier)* @staticKeyword
       type: (_)* @type ;;class constructor won't have a type, so we need to be able to match on zero or more types
       [
        (function_declarator) @valueReturn
        (pointer_declarator (function_declarator)) @pointerReturn
        (reference_declarator (function_declarator)) @referenceReturn
        ]
       ) @templateOrConstructorDeclaration
     ]

