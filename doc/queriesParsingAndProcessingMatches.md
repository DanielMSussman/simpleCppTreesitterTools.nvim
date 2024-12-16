# Working with custom treesitter queries in neovim

As mentioned in the main README, I think the existing documentation for working with custom treesitter queries is quite good. 
There were, however, a few points where the main treesitter and nvim-treesitter docs were not quite clear enough for me --- a beginner both in working with treesitter and in writing Lua code at all --- to know exactly how to do what I wanted.
As in many cases, I mostly figured things out by (a) copious use of `vim.notify()` and `print(vim.inspect())` throughout the functions I was writing and (b) starting at much more sophisticated code used in other plugins.
I thought it might be helpful to clean up some of the notes I took while learning in case they're useful to others who want to use treesitter to do some fun things.

## Queries

Step one in writing a query to do something is to start getting used to the structure of nodes in the language tree associated with your file. 
The built-in neovim command `:InspectTree` is absolutely invaluable here ---

TODO: add an image with a simple header and a simple cpp implementation, and description

---

The documentation for [treesitter itself](https://tree-sitter.github.io/tree-sitter/) is excellent for understanding how to write queries that target different parts of the tree and patterns within it.
Along with the ability to inspect the tree associated with a buffer, another built-in command (`:EditQuery`) can be used to play around --- writing different queries and seeing what parts of the code are matched on that query and how those matches get sorted into "capture groups" that we'll be able to process later.
This combination of a view of the tree for the given buffer and live feedback on writing queries makes it easy to iterate and quickly learn how writing queries really works.

### Example queries

I've tried to liberally add comments on the [custom queries used in this plugin](/lua/simpleCppTreesitterTools/customTreesitterQueries.lua).
In case it's helpful, though, I'll give just a few examples here.

#### Single-node queries

The simplest query is what that matches on any specific node in the language tree. For instance, in a lua file one could define a local query like so:
```lua
local query = vim.treesitter.query.parse("cpp",
    [[
    (function_definition) @functionDefinition
    ]]
)
```
If we run this query on a buffer (see below) we'll get a match on every node in the tree which is a `function_definition`. The "at" symbol sets up a capture that we'll be able to access (again, see below) --- the name we give to it is irrelevant, and I tend to just use a camel-case version of the kind of node I'm capturing.

#### Queries with more structure

One can, of course, do much more than just query for individual nodes.
Much more powerful are queries that look for nodes that have structure in their sub-tree.
For instance, suppose we want to find template declarations, but *only* if the declaration is of a templated class (rather than, say, also match on template functions). The following local query will do the trick, looking for a `template_declaration` that has a `class_specifier` as one of its children (while simultaneously capturing the `template_parameter_list` node for future use):
```lua
local query = vim.treesitter.query.parse("cpp",
    [[
    (template_declaration
      (template_parameter_list) @templateParameterList
      (class_specifier) 
      ) @classTemplate
    ]]
)
```

#### Alternates, optional nodes, and wildcard nodes

The treesitter documentation has a lot more information about the much richer structure you can build queries out of (anchors, predicates, named and anonymous nodes,...), but there are a small number of query-constructing options that I find most useful.
First is the ability to specify that the query should succeed on either *this* or *that* kind of node. These "alternation" nodes are specified with square brackets. For example, this:
```lua
    [
    (parameter_declaration)
    (optional_parameter_declaration)
    ]@parameterDeclaration
```
will match on either of the listed node types. A `?` after a node type says that finding such a node is optional --- the query will match with or without it, but this can be useful for capturing those nodes which sometimes appear.
Finally, a wildcard node, `(_)`, allows one to match on *any* node (which can be handy when you do not want to list out all of the possible alternatives explicitly.
Combining these ideas, here's a query that I use to parse function parameter lists:
```lua
local query = vim.treesitter.query.parse("cpp",
    [[
    [
     (parameter_declaration
        (
        (type_qualifier)? @typeQualifier
        type: (_) @typeId
        declarator: (_) @variableName
            )
        )@parameterDeclaration
     (optional_parameter_declaration
        (
        (type_qualifier)? @typeQualifier
        type: (_) @typeId
        declarator: (_) @variableName
            )
        )@parameterDeclaration
    ]
    ]]
)
```
Here the optional `type_qualifier` lets us capture whether one of the arguments in the parameter list is `const`.
The wildcard on the type of the `parameter_declaration` will correctly capture a `primitive_type` (void, int, float...), a `qualified_identifier` (e.g, a `std::vector<int>`), or a `type_identifier` (e.g., a custom structure being used as a type).

This could have been even more succinct, by using a wildcard node at the top instead of the explicit alternates that have the same child structure.
```lua
local query = vim.treesitter.query.parse("cpp",
    [[
    parameters: (parameter_list
        (_
            (
            (type_qualifier)? @typeQualifier
            type: (_) @typeId
            declarator: (_) @variableName
            )
        )@parameterDeclaration
      ) @parameterList
    ]]
)
```

## Processing matches on queries

Now that we've written a few queries, there are a few ways we can actually run those queries on a buffer (or a string --- see below): the `iter_captures(...)` and `iter_matches(...)` functions.
For whatever reason the `iter_matches` approach feels more natural to me, so that's what I'll describe here (and it's mostly what's used in the plugin). In it's simplest form, suppose we have a `local query =...` defined (perhaps a la one of the examples above). We can then write:
```lua
local matches = query:iter_matches(node,0)
```
where the `node` is a node of the tree you want the query to use as the root of the search, and here `0` is the buffer that will be used as the source. 

There are two other optional arguments that can be used to control the start and end of the query within the source --- I'm not going to use that here.
We now have stored in `matches` all of the results of running our query on the sub-tree that starts at the given node. We can loop through these matches like so:
```lua
for id, match, metadata in matches do 
    local capturedNode1 = match[1]
    -- local capturedNode2 = match[2]
    -- add code that *uses* these nodes here
    --for instance, local text = vim.treesitter.get_node_text(capturedNode1,0)
end
```
That is: what I've written as `match` is a table of captured nodes (some of which might be `nil`, for instance if the node was optional in the query). What order do these nodes appear in this table? 
As far as I can tell, it corresponds to the order that the names of the capture groups appear in the query.
You can explicitly verify this, though, by looking at the `captures` table in the query itself:
```lua
for i,captures in ipairs(query.captures) do 
    vim.notify(tostring(i).." "..captures)
end
```

## Parsing arbitrary strings

The above approach works well for running a query on a buffer, but what about running the same query on an arbitrary string?
In this plugin, for instance, I want to query a `.cpp` file which might not be in a buffer to see if a member function has already been implemented.
Neovim has provided us with a string parser for just such an occasion. The following will read a file (for present purposes, let's assume the file definitely exists), and then run a particularly simple query on it:
```lua
local query = vim.treesitter.query.parse("cpp",
    [[
    (function_definition) @functionDefinition
    ]]
) 
local fileContent = vim.fn.readfile(fileName)
local fileString = table.concat(fileContent,"\n")
local parser = vim.treesitter.get_string_parser(fileString,"cpp")
local tree = parser:parse()
local rootNode = tree[1]:root()
local matches = query:iter_matches(rootNode, fileString)
```
As is hopefully clear from the names, this defines a simple query, reads in a file, concatenates the file into a single string (separated by newlines, in this case, because I want to know the line number a node might be on for later use), gets a parser with the right language for that content, finds the root of the resulting tree, and then runs the `iter_matches` function with that query (using the root of the tree as the starting point, and using the stringified version of the file as the source).
