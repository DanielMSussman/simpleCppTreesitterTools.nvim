# Guide to files in this directory

Below is a brief summary of how I've organized the different lua files that make up this plugin.
If you're interested in writing queries then the `customTreesitterQueries` file is the place to start.
The `simpleTreesitterUtilities` file is where to go to find examples of iterating through and processing those queries


## `init.lua`

The `init.lua` files is that one that gets directly loaded when the plugin is setup.
It contains the configuration options, and uses the `nvim_create_user_command` api
to connect user commands to the functionality of the plugin.

## `customTreesitterQueries.lua`

A file full of the specific treesitter queries that are used in other functions by the plugin.

## `simpleTreesitterUtilities.lua`

A collection of functions who's main purpose is to run the queries defined in the `customTreesitterQueries` file.
Those functions typically also do a lot of the relevant parsing of query results.
A few handy tree-traversal functions (e.g., "climb the tree until you find a node of a specific type") are also included.


## `cppModule.lua`

Most of the business logic of the plugin. The functions here are (a) directly called by the commands defined in `init.lua`,
(b) are used to interface with the query-parsing functions in `simpleTreesitterUtilities`, or 
(c) based on organizing the results of those interfaces into the actual strings we want to put into implementation (or new header) files.


## `fileHelpers.lua`

Various helper functions for reading / writing files, checking buffers, and manipulating file names.
