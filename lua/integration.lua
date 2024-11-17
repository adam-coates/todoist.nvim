local api = require('todoist.api')
local utils = require('todoist.utils')
local ui = require('todoist.ui')
local config = require('todoist').config

local M = {}

local data = nil
local buf = nil
local timer = nil
local task_ids = {}

local function get_task_id_from_line(line_nr)
  return task_ids[line_nr]
end

local function refresh_tasks()
  data = api.fetch_data()
  if not data then return end
  
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  local lines = {
    "# Todoist Tasks",
    "----------------------",
    "Press <Enter> on empty line to add new task",
    "Press c to toggle task completion",
    "Press dd to delete task",
    "Press r to refresh tasks",
    "",
  }
  
  task_ids = {}
  
  local projects = {}
  local project_names = {}
  
  for _, project in ipairs(data.projects) do
    projects[project.id] = {
      name = project.name,
      tasks = {},
      id = project.id
    }
    table.insert(project_names, {
      name = project.name,
      id = project.id
    })
  end
  
  for _, item in ipairs(data.items) do
    if type(item) == "table" and item.content then
      local project_id = item.project_id
      if projects[project_id] then
        table.insert(projects[project_id].tasks, item)
      end
    end
  end
  
  table.sort(project_names, function(a, b)
    if a.name == "Inbox" then return true
    elseif b.name == "Inbox" then return false
    else return a.name:lower() < b.name:lower() end
  end)
  
  for _, project_info in ipairs(project_names) do
    local project = projects[project_info.id]
    table.insert(lines, "### " .. project.name)
    
    if #project.tasks > 0 then
      table.sort(project.tasks, function(a, b)
        local priority_a = a.priority or 1
        local priority_b = b.priority or 1
        return priority_a > priority_b
      end)
      
      for _, task in ipairs(project.tasks) do
        local checkbox = task.checked and "[x]" or "[ ]"
        local priority_str = utils.get_priority_string(task.priority)
        local due_str = utils.get_due_string(task)
        local task_line = string.format("- %s %s%s %s", checkbox, task.content, due_str, priority_str)
        table.insert(lines, task_line)
        task_ids[#lines - 1] = task.id
      end
    end
    table.insert(lines, "")
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function setup_keymaps()
  local opts = { noremap = true, silent = true, buffer = buf }
  
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    
    if line:match('^%s*$') or line:match('^-%s*%[%s*%]') then
      local new_task = vim.fn.input('New task: ')
      if new_task ~= '' then
        add_task(new_task, current_line)
        refresh_tasks()
      end
    end
  end, opts)
  
  vim.keymap.set('n', 'c', function()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local task_id = get_task_id_from_line(line_nr - 1)
    if task_id then
      toggle_task(task_id)
      refresh_tasks()
    end
  end, opts)
  
  vim.keymap.set('n', 'dd', function()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local task_id = get_task_id_from_line(line_nr - 1)
    if task_id then
      if vim.fn.confirm('Delete this task?', '&Yes\n&No') == 1 then
        delete_task(task_id)
        refresh_tasks()
      end
    end
  end, opts)
  
  vim.keymap.set('n', 'r', function()
    refresh_tasks()
    print("Tasks refreshed!")
  end, opts)
end

function M.open_todoist()
  if not os.getenv("TODOIST_API_KEY") then
    print("Error: TODOIST_API_KEY environment variable not set")
    return
  end

  -- Create buffer if it doesn't exist
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_name(buf, 'Todoist Tasks')
    
    -- Set up autocmds
    vim.api.nvim_create_autocmd("BufWinEnter", {
      buffer = buf,
      callback = function()
        ui.setup_todoist_syntax()
      end
    })
    
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      callback = function()
        if timer then
          timer:stop()
          timer:close()
          timer = nil
        end
      end
    })
    
    setup_keymaps()
  end

  -- Create or switch to window
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd('vsplit')
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  else
    vim.fn.win_gotoid(win)
  end

  -- Initial refresh and setup auto-refresh
  refresh_tasks()
  
  if not timer then
    timer = vim.loop.new_timer()
    timer:start(0, config.auto_refresh_interval, vim.schedule_wrap(function()
      refresh_tasks()
    end))
  end
end

-- Helper functions for task management
local function get_priority()
  local priority = vim.fn.input("Enter priority (1-4, Enter for default): ")
  if priority ~= "" then
    priority = tonumber(priority)
    if priority and priority >= 1 and priority <= 4 then
      return 5 - priority  -- Convert display priority to Todoist priority
    end
  end
  return 1
end

local function get_due_date()
  local date_string = vim.fn.input("Enter due date (e.g., 'tomorrow at 10:00', 'monday at 15:00', or press Enter to skip): ")
  if date_string ~= "" then
    return { string = date_string }
  end
  return nil
end

local function get_project_selection()
  if not data or not data.projects then return nil end
  
  local project_names = {}
  local project_ids = {}
  for _, project in ipairs(data.projects) do
    table.insert(project_names, project.name)
    table.insert(project_ids, project.id)
  end
  
  local selected_idx = vim.fn.index(project_names, vim.fn.input("Select project (press Tab to complete): ", "", "customlist," .. table.concat(project_names, "\n"))) + 1
  if selected_idx > 0 then
    return project_ids[selected_idx]
  end
  
  -- Default to Inbox
  for i, project in ipairs(data.projects) do
    if project.name == "Inbox" then
      return project.id
    end
  end
  
  return data.projects[1].id
end

local function add_task(content, current_line)
  if not data or not data.projects or #data.projects == 0 then
    print("No projects available")
    return
  end

  local project_id = nil
  local current_project = nil
  
  for i = current_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if line and line:match("^### (.+)$") then
      current_project = line:match("^### (.+)$")
      break
    end
  end
  
  if current_project then
    for _, project in ipairs(data.projects) do
      if project.name == current_project then
        project_id = project.id
        break
      end
    end
  end
  
  if not project_id then
    project_id = get_project_selection()
  end

  local due = get_due_date()
  local priority = get_priority()

  local task_temp_id = utils.generate_uuid()
  local commands = {
    {
      type = "item_add",
      temp_id = task_temp_id,
      uuid = utils.generate_uuid(),
      args = {
        content = content,
        project_id = project_id,
        priority = priority,
        due = due
      }
    }
  }

  api.execute_commands(commands, data.sync_token)
end

local function toggle_task(task_id)
  local commands = {
    {
      type = "item_close",
      uuid = utils.generate_uuid(),
      args = {
        id = task_id
      }
    }
  }
  api.execute_commands(commands, data.sync_token)
end

local function delete_task(task_id)
  local commands = {
    {
      type = "item_delete",
      uuid = utils.generate_uuid(),
      args = {
        id = task_id
      }
    }
  }
  api.execute_commands(commands, data.sync_token)
end

return M
