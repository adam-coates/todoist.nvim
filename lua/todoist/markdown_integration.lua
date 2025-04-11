-- markdown_integration.lua
local api = require('todoist.api')
local utils = require('todoist.utils')
local config = require('todoist').config

local M = {}

-- Cache for tasks data
M.data = nil
-- Track active todoist blocks in buffers
M.active_blocks = {}
-- Track task IDs per line in each buffer
M.buffer_task_ids = {}

-- Refresh tasks data from API
function M.refresh_data()
  M.data = api.fetch_data()
  return M.data
end

-- Find all todoist code blocks in the current buffer
function M.find_todoist_blocks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local in_block = false
  local start_line = nil
  local filter = "today" -- Default filter
  
  for i, line in ipairs(lines) do
    if line:match("^```todoist") then
      in_block = true
      start_line = i
      
      -- Extract filter if specified
      local filter_match = line:match("filter:%s*(%S+)")
      if filter_match then
        filter = filter_match
      end
    elseif in_block and line:match("^```$") then
      in_block = false
      table.insert(blocks, {
        start_line = start_line,
        end_line = i,
        filter = filter
      })
      filter = "today" -- Reset to default
    end
  end
  
  return blocks
end

-- Safe check for due date
function M.get_due_date(task)
  -- Check if task has due property and it's a table
  if not task.due then
    return nil
  end
  
  -- Handle different API response formats
  if type(task.due) == "table" and task.due.date then
    return task.due.date
  elseif type(task.due) == "string" then
    return task.due
  else
    -- Try to handle userdata case or other unexpected formats
    local success, result = pcall(function() return tostring(task.due) end)
    if success then
      return result
    else
      return nil
    end
  end
end

-- Filter tasks based on criteria
function M.filter_tasks(filter)
  if not M.data or not M.data.items then
    return {}
  end
  
  local filtered_tasks = {}
  local today = os.date("%Y-%m-%d")
  local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
  
  if filter == "today" then
    -- Filter tasks due today or overdue
    for _, task in ipairs(M.data.items) do
      if not task.checked then
        local due_date = M.get_due_date(task)
        if due_date and due_date <= today then
          table.insert(filtered_tasks, task)
        end
      end
    end
  elseif filter == "tomorrow" then
    -- Filter tasks due tomorrow
    for _, task in ipairs(M.data.items) do
      if not task.checked then
        local due_date = M.get_due_date(task)
        if due_date and due_date == tomorrow then
          table.insert(filtered_tasks, task)
        end
      end
    end
  elseif filter == "upcoming" then
    -- Filter tasks due in the next 7 days
    local seven_days = os.time() + (7 * 86400)
    local seven_days_date = os.date("%Y-%m-%d", seven_days)
    
    for _, task in ipairs(M.data.items) do
      if not task.checked then
        local due_date = M.get_due_date(task)
        if due_date and due_date > today and due_date <= seven_days_date then
          table.insert(filtered_tasks, task)
        end
      end
    end
  elseif filter == "overdue" then
    -- Filter overdue tasks
    local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
    
    for _, task in ipairs(M.data.items) do
      if not task.checked then
        local due_date = M.get_due_date(task)
        if due_date and due_date <= yesterday then
          table.insert(filtered_tasks, task)
        end
      end
    end
  elseif filter:match("^project:") then
    -- Filter by project name
    local project_name = filter:match("^project:(.+)")
    local project_id = nil
    
    -- Find project ID by name
    for _, project in ipairs(M.data.projects) do
      if project.name:lower() == project_name:lower() then
        project_id = project.id
        break
      end
    end
    
    if project_id then
      for _, task in ipairs(M.data.items) do
        if not task.checked and task.project_id == project_id then
          table.insert(filtered_tasks, task)
        end
      end
    end
  else
    -- Default: show all incomplete tasks
    for _, task in ipairs(M.data.items) do
      if not task.checked then
        table.insert(filtered_tasks, task)
      end
    end
  end
  
  -- Sort tasks by priority
  table.sort(filtered_tasks, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    else
      return a.content < b.content
    end
  end)
  
  return filtered_tasks
end

-- Render tasks in a specific block
function M.render_block(bufnr, block)
  if not M.data then
    M.refresh_data()
  end
  
  if not M.data then
    -- If we still don't have data, create a placeholder
    local new_lines = {
      string.format("```todoist"),
      string.format("filter: %s", block.filter),
      "Error: Could not fetch Todoist data",
      "Make sure your TODOIST_API_KEY is set correctly",
      "Press r to try again",
      "```"
    }
    
    -- Save the current modifiable state
    local was_modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
    
    -- Set modifiable temporarily
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(bufnr, block.start_line - 1, block.end_line, false, new_lines)
    
    -- Restore previous modifiable state
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', was_modifiable)
    
    block.end_line = block.start_line + #new_lines - 1
    return block
  end
  
  -- Get tasks based on filter
  local tasks = M.filter_tasks(block.filter)
  
  -- Create new lines for the block
  local new_lines = {
    string.format("```todoist"),
    string.format("filter: %s", block.filter)
  }
  
  -- Track task IDs for this buffer
  if not M.buffer_task_ids[bufnr] then
    M.buffer_task_ids[bufnr] = {}
  end
  
  -- Add tasks to block
  for i, task in ipairs(tasks) do
    local checkbox = task.checked and "[x]" or "[ ]"
    local priority_str = utils.get_priority_string(task.priority)
    local due_str = utils.get_due_string(task)
    local task_line = string.format("%d. %s %s%s %s", i, checkbox, task.content, due_str, priority_str)
    table.insert(new_lines, task_line)
    
    -- Store the task ID for this line
    local line_num = block.start_line + #new_lines - 1
    M.buffer_task_ids[bufnr][line_num] = task.id
  end
  
  -- Add instruction line if no tasks
  if #tasks == 0 then
    table.insert(new_lines, "No tasks matching filter")
  end
  
  -- Add instructions footer
  table.insert(new_lines, "")
  table.insert(new_lines, "Press <Enter> on line to complete/uncomplete task")
  table.insert(new_lines, "Press r to refresh tasks")
  table.insert(new_lines, "Press a to add new task")
  table.insert(new_lines, "```")
  
  -- Save the current modifiable state
  local was_modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
  
  -- Replace block content
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, block.start_line - 1, block.end_line, false, new_lines)
  
  -- Restore previous modifiable state
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', was_modifiable)
  
  -- Update block end line for tracking
  block.end_line = block.start_line + #new_lines - 1
  
  return block
end
-- Render all todoist blocks in buffer
function M.render_all_blocks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local blocks = M.find_todoist_blocks(bufnr)
  
  -- Clear existing task IDs for this buffer
  M.buffer_task_ids[bufnr] = {}
  
  -- Track active blocks
  M.active_blocks[bufnr] = {}
  
  for _, block in ipairs(blocks) do
    local updated_block = M.render_block(bufnr, block)
    table.insert(M.active_blocks[bufnr], updated_block)
  end
end

-- Toggle task completion
function M.toggle_task(bufnr, line_nr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local task_id = M.buffer_task_ids[bufnr] and M.buffer_task_ids[bufnr][line_nr]
  
  if not task_id then return end
  
  -- Find the task
  local task = nil
  for _, item in ipairs(M.data.items) do
    if item.id == task_id then
      task = item
      break
    end
  end
  
  if not task then return end
  
  -- Toggle completion
  local command_type = task.checked and "item_uncomplete" or "item_close"
  
  local commands = {
    {
      type = command_type,
      uuid = utils.generate_uuid(),
      args = {
        id = task_id
      }
    }
  }
  
  -- Execute command and refresh data
  api.execute_commands(commands, M.data.sync_token)
  M.refresh_data()
  
  -- Re-render all blocks
  M.render_all_blocks(bufnr)
end

-- Add a new task
function M.add_task(bufnr, line_nr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Find which block we're in
  local current_block = nil
  if M.active_blocks[bufnr] then
    for _, block in ipairs(M.active_blocks[bufnr]) do
      if line_nr >= block.start_line and line_nr <= block.end_line then
        current_block = block
        break
      end
    end
  end
  
  if not current_block then return end
  
  -- Get task details
  local content = vim.fn.input("Task: ")
  if content == "" then return end
  
  -- Get project based on filter
  local project_id = nil
  if current_block.filter:match("^project:") then
    local project_name = current_block.filter:match("^project:(.+)")
    for _, project in ipairs(M.data.projects) do
      if project.name:lower() == project_name:lower() then
        project_id = project.id
        break
      end
    end
  end
  
  -- If no project specified, use Inbox or first project
  if not project_id then
    for _, project in ipairs(M.data.projects) do
      if project.name == "Inbox" then
        project_id = project.id
        break
      end
    end
    
    if not project_id and #M.data.projects > 0 then
      project_id = M.data.projects[1].id
    end
  end
  
  -- Check if we should set a due date based on filter
  local due = nil
  if current_block.filter == "today" then
    due = { string = "today" }
  elseif current_block.filter == "tomorrow" then
    due = { string = "tomorrow" }
  elseif current_block.filter == "upcoming" then
    -- Ask for due date within next 7 days
    local date_input = vim.fn.input("Due date (within next 7 days): ")
    if date_input ~= "" then
      due = { string = date_input }
    end
  end
  
  -- If no due date set by filter, ask user
  if not due then
    local date_input = vim.fn.input("Due date (optional): ")
    if date_input ~= "" then
      due = { string = date_input }
    end
  end
  
  -- Get priority
  local priority_input = vim.fn.input("Priority (1-4, Enter for default): ")
  local priority = 1 -- Default
  if priority_input ~= "" then
    priority = tonumber(priority_input)
    if priority and priority >= 1 and priority <= 4 then
      priority = 5 - priority  -- Convert display priority to Todoist priority
    else
      priority = 1
    end
  end
  
  -- Add the task
  local task_temp_id = utils.generate_uuid()
  local commands = {}
  local task_args = {
    content = content,
    project_id = project_id,
    priority = priority
  }
  
  if due then
    task_args.due = due
  end
  
  table.insert(commands, {
    type = "item_add",
    temp_id = task_temp_id,
    uuid = utils.generate_uuid(),
    args = task_args
  })
  
  -- Execute command and refresh data
  api.execute_commands(commands, M.data.sync_token)
  M.refresh_data()
  
  -- Re-render all blocks
  M.render_all_blocks(bufnr)
end

-- Set up keymaps for todoist code blocks
function M.setup_keymaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Create buffer-local keymaps
  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', 
    [[<cmd>lua require('todoist.markdown_integration').handle_enter()<CR>]], 
    { noremap = true, silent = true })
    
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'r', 
    [[<cmd>lua require('todoist.markdown_integration').refresh_current_buffer()<CR>]], 
    { noremap = true, silent = true })
    
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'a', 
    [[<cmd>lua require('todoist.markdown_integration').handle_add_task()<CR>]], 
    { noremap = true, silent = true })
end

-- Handle Enter key press
function M.handle_enter()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  
  -- Check if we're in a task line
  if M.buffer_task_ids[bufnr] and M.buffer_task_ids[bufnr][line_nr] then
    M.toggle_task(bufnr, line_nr)
  end
end

-- Handle adding a task
function M.handle_add_task()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  
  M.add_task(bufnr, line_nr)
end

-- Refresh current buffer
function M.refresh_current_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  M.refresh_data()
  M.render_all_blocks(bufnr)
  print("Todoist tasks refreshed")
end

-- Initialize markdown integration
function M.setup()
  -- Create autocommands for markdown files
  local todoist_group = vim.api.nvim_create_augroup("TodoistMarkdown", { clear = true })
  
  -- Detect markdown files with todoist code blocks
  vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = todoist_group,
    callback = function(args)
      local blocks = M.find_todoist_blocks(args.buf)
      if #blocks > 0 then
        -- Set up keymaps for this buffer
        M.setup_keymaps(args.buf)
        
        -- Render todoist blocks
        M.render_all_blocks(args.buf)
      end
    end
  })
  
  -- Protect todoist blocks from direct editing
  vim.api.nvim_create_autocmd({"InsertEnter", "InsertCharPre"}, {
    pattern = "*.md",
    group = todoist_group,
    callback = function(args)
      -- Check if cursor is in a todoist block
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_nr = cursor[1]
      
      -- Check if we're in a todoist block
      local in_todoist_block = false
      if M.active_blocks[args.buf] then
        for _, block in ipairs(M.active_blocks[args.buf]) do
          if line_nr >= block.start_line and line_nr <= block.end_line then
            in_todoist_block = true
            break
          end
        end
      end
      
      -- If in a todoist block, prevent editing
      if in_todoist_block then
        vim.api.nvim_input("<Esc>")
        vim.api.nvim_echo({{
          "Todoist blocks cannot be edited directly. Use the provided key commands to interact with tasks.",
          "WarningMsg"
        }}, true, {})
        return true -- Cancel the event
      end
    end
  })
  
  -- Set up syntax highlighting for todoist blocks
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    group = todoist_group,
    callback = function()
      vim.cmd([[
        syntax match markdownTodoistTask "^\d\+\. \[\s*\] .*$" contained containedin=markdownCodeBlock
        syntax match markdownTodoistDone "^\d\+\. \[x\] .*$" contained containedin=markdownCodeBlock
        syntax match markdownTodoistDueToday "(Due: \(today\|.*today.*\))" contained containedin=markdownCodeBlock
        syntax match markdownTodoistPriority "\[P[1-3]\]" contained containedin=markdownCodeBlock
        
        highlight default link markdownTodoistTask Todo
        highlight default link markdownTodoistDone Comment
        highlight default link markdownTodoistDueToday Error
        highlight default link markdownTodoistPriority WarningMsg
      ]])
    end
  })
end

return M
