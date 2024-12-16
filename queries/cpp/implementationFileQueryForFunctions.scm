    (function_definition
      type: (_)? @type
      [
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
        (pointer_declarator
      (function_declarator
        (
        (qualified_identifier
          [
           (identifier) @functionName
           (destructor_name) @functionName
           ]) @qualifiedID
        (parameter_list) @parameterList
                )
                )) @funcDecl
        (reference_declarator
      (function_declarator
        (
        (qualified_identifier
          [
           (identifier) @functionName
           (destructor_name) @functionName
           ]) @qualifiedID
        (parameter_list) @parameterList
                )
                )) @funcDecl
    ]
        )@funcDefinition

