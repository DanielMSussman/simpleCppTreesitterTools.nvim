# cppTools.nvim 

Does stuff

# Install

## lazy.nvim
```lua
{
dir="~/repos/code/cpptools.nvim",
dependencies = { 'nvim-treesitter/nvim-treesitter'},
config = function()
    require("cpptools").setup({
        verbosenotifications = true,
        })

    vim.api.nvim_create_user_command("implementeverything",
        function()
            require("cpptools").implementeverythinginclass()
        end,{desc = 'call the implementeverything function'}
    )
    vim.keymap.set("n", "<localleader>c", function() vim.cmd("implementeverything") end,{desc = 'implement class member declarations in [c]pp file'})
end
}
```

# learning

https://m.youtube.com/watch?v=_m7amJZpQQ8

https://m.youtube.com/watch?v=IRd2zwF527M&pp=ygUKVHJlZXNpdHRlcg%3D%3D

refactoring. nvim

NT CPP TreeSitter Tools nvim
