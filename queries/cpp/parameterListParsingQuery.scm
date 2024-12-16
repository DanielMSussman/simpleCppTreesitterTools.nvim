    [
     (parameter_declaration
        (
        (type_qualifier)? @typeQualifier
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

