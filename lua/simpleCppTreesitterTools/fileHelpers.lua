local M = {}

-- Slightly misnamed --- this returns the name of the current buffer's file without any path information
M.getLocalHeaderName = function()
    return vim.fn.expand("%:t")
end

M.getAbsoluteFilenames = function(headerExtension,implementationExtension)
    local currentFile = vim.fn.expand("%:p")
    local cppFilename = currentFile:gsub("%.h$", ".cpp")

    local testName = currentFile:gsub(headerExtension .. "$", implementationExtension)
    return currentFile, cppFilename
end

--[[ read in a file (with no checks that it definitely exists!), and create a table with all of the lines.
Insert the desired content in the specified line, or append to the end of the table.
]]-- Write the contents back out to the file
M.insertLinesIntoFile = function(filename, lines, lineNumber,dontWrite)
    if vim.fn.filereadable(filename) == 0 then
        return nil,nil
    end
    local fileContent = vim.fn.readfile(filename)

    -- Insert the new lines at the specified line number
    if lineNumber  > 0 and lineNumber <= #fileContent then
        for i = #lines, 1, -1 do
            table.insert(fileContent, lineNumber, lines[i])
        end
    else
        -- If lineNumber is beyond the end of the file, append the lines
        vim.list_extend(fileContent, lines)
    end

    -- Write the modified content back to the file
    if not dontWrite then
        vim.fn.writefile(fileContent, filename)
    end
end

-- check if the file is, indeed, currently open as a buffer
M.fileIsOpenInBuffer = function(filename)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == filename then
      return true
    end
  end
  return false
end

-- use checktime to force the screen to update if the file is currently open
M.refreshImplementationBuffer = function(implementationFile)
    if M.fileIsOpenInBuffer(implementationFile) then
        vim.cmd("checktime "..implementationFile)
    end 
end

-- create the file if it doesn't exist, and add the "#include headerName.h" line
M.createIncludingFileIfItDoesNotExist = function(implementationFile, dontWrite)
    local fileIsReadable = vim.fn.filereadable(implementationFile)
    if fileIsReadable == 0 then
        local header = M.getLocalHeaderName()
        local contentToAppend={}
        table.insert(contentToAppend,"#include \""..header.."\"")

        if not dontWrite then
            vim.fn.writefile(contentToAppend,implementationFile,"a")
        end
    end
end

--[[
for creating a file with a derived class... input the desired content,
then wrap it with header guards and an include headerName line
]]--
M.createDerivedFileWithHeaderGuards = function(fileName,fileContent, dontWrite)
    local header = M.getLocalHeaderName()
    table.insert(fileContent,1,"#include \""..header.."\"")
    local guardString = fileName:match("([^\\/]+)$") 
    guardString = string.upper(string.gsub(guardString,"%.","_"))

    table.insert(fileContent,1,"")
    table.insert(fileContent,1,"#define "..guardString)
    table.insert(fileContent,1,"#ifndef "..guardString)

    table.insert(fileContent,"")
    table.insert(fileContent,"#endif")
    if not dontWrite then
        vim.fn.writefile(fileContent,fileName,"a")
    end
    return fileContent
end

return M
