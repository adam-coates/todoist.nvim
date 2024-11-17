local utils = require('todoist.utils')
local config = require('todoist').config

local M = {}

function M.fetch_data()
  local token = os.getenv("TODOIST_API_KEY")
  local sync_command = string.format(
    'curl -s "https://api.todoist.com/sync/v9/sync" -H "Authorization: Bearer %s" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "sync_token=*" --data-urlencode \'resource_types=["items","projects"]\'',
    token
  )
  
  local sync_result = vim.fn.system(sync_command)
  return utils.safe_json_decode(sync_result)
end

function M.execute_commands(commands, sync_token)
  if not commands or #commands == 0 then return end
  
  local token = os.getenv("TODOIST_API_KEY")
  local commands_json = vim.json.encode(commands)
  local update_command = string.format(
    'curl -s "https://api.todoist.com/sync/v9/sync" -H "Authorization: Bearer %s" -H "Content-Type: application/x-www-form-urlencoded" -d "sync_token=%s" -d "commands=%s"',
    token,
    sync_token,
    commands_json:gsub('"', '\\"')
  )

  local result = vim.fn.system(update_command)
  return utils.safe_json_decode(result)
end

return M
