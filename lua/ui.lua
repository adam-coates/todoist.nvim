local config = require('todoist').config

local M = {}

function M.setup_todoist_syntax()
  -- Clear existing syntax in case of refresh
  vim.cmd([[syntax clear]])

  -- Get today's date and format dates for comparison
  local today = os.date("*t")
  local tomorrow = os.time({year=today.year, month=today.month, day=today.day + 1})
  local three_days = os.time({year=today.year, month=today.month, day=today.day + 3})
  
  -- Format dates for pattern matching
  local today_str = os.date("%d %b", os.time(today))
  local tomorrow_str = os.date("%d %b", tomorrow)
  local three_days_str = os.date("%d %b", three_days)

  -- Define syntax patterns
  vim.cmd(string.format([[
    syntax match TodoistProject "^### .*$"
    syntax match TodoistDueToday "(Due: \(%s\|today\)[^)]*)"
    syntax match TodoistDueTomorrow "(Due: \(%s\|tomorrow\)[^)]*)"
    syntax match TodoistDueThreeDays "(Due: \([^)]*\(%s\|in 2 days\|in 3 days\)[^)]*\))"
    syntax match TodoistDueLater "(Due: [^)]*)" contains=TodoistDueToday,TodoistDueTomorrow,TodoistDueThreeDays
    syntax match TodoistCheckbox "\[ \]"
    syntax match TodoistCheckedBox "\[x\]"
    syntax match TodoistHeader "^# Todoist Tasks$"
    syntax match TodoistHeaderLine "^----------------------$"
    syntax match TodoistInstructions "^Press.*$"
    syntax match TodoistPriority1 "\[P1\]" contains=TodoistCheckbox,TodoistCheckedBox
    syntax match TodoistPriority2 "\[P2\]" contains=TodoistCheckbox,TodoistCheckedBox
    syntax match TodoistPriority3 "\[P3\]" contains=TodoistCheckbox,TodoistCheckedBox
  ]], today_str, tomorrow_str, three_days_str))

  -- Define highlighting using colors from config
  local highlights = {
    TodoistProject = { fg = config.highlight.project, gui = "bold" },
    TodoistDueToday = { fg = config.highlight.due_today, gui = "bold" },
    TodoistDueTomorrow = { fg = config.highlight.due_tomorrow },
    TodoistDueThreeDays = { fg = config.highlight.due_upcoming },
    TodoistDueLater = { fg = config.highlight.due_later },
    TodoistCheckbox = { fg = config.highlight.checkbox },
    TodoistCheckedBox = { fg = config.highlight.checked },
    TodoistHeader = { fg = config.highlight.header, gui = "bold" },
    TodoistHeaderLine = { fg = config.highlight.header_line },
    TodoistInstructions = { fg = config.highlight.instructions, gui = "italic" },
    TodoistPriority1 = { fg = config.highlight.priority1, gui = "bold" },
    TodoistPriority2 = { fg = config.highlight.priority2 },
    TodoistPriority3 = { fg = config.highlight.priority3 }
  }

  for group, colors in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, colors)
  end
end

return M
