-- It turns out you have to do the dirty work yourself. At least it can be stuffed over here in the corner
local M = {}


M.getLocalHeaderName = function()
    return vim.fn.expand("%:t")
end

M.getAbsoluteFilenames = function()
    local currentFile = vim.fn.expand("%:p")
    local cppFilename = currentFile:gsub("%.h$", ".cpp")
    return currentFile, cppFilename
end

M.fileIsOpenInBuffer = function(filename)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == filename then
      return true
    end
  end
  return false
end

M.refreshImplementationBuffer = function(implementationFile)
    if M.fileIsOpenInBuffer(implementationFile) then
        vim.cmd("checktime "..implementationFile)
    end 
end

M.createIncludingFileIfItDoesNotExist = function(implementationFile)

    local fileIsReadable = vim.fn.filereadable(implementationFile)
    if fileIsReadable == 0 then
        local header = M.getLocalHeaderName()
        local contentToAppend={}
        table.insert(contentToAppend,"#include \""..header.."\"")
        vim.fn.writefile(contentToAppend,implementationFile,"a")
    end

end
return M
