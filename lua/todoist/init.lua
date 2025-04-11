local M = {}

-- Configuration with defaults
M.config = {
  auto_refresh_interval = 30000, -- 30 seconds
  highlight = {
    priority1 = "#ff0000",
    priority2 = "#ff8c00",
    priority3 = "#0087ff",
    due_today = "#e06c75",
    due_tomorrow = "#e5c07b",
    due_upcoming = "#98c379",
    due_later = "#56b6c2",
    project = "#61afef",
    checkbox = "#abb2bf",
    checked = "#98c379",
    header = "#c678dd",
    header_line = "#545862",
    instructions = "#abb2bf",
  },
  -- New configuration options for markdown integration
  markdown = {
    enabled = false,
    auto_refresh = false,
  }
}

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Create the command only after setup
  vim.api.nvim_create_user_command('Todoist', function()
    require('todoist.integration').open_todoist()
  end, {})
  
  -- Initialize markdown integration if enabled
  if M.config.markdown.enabled then
    require('todoist.markdown_integration').setup()
  end
end

return M

