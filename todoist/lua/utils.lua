local M = {}

function M.safe_json_decode(str)
  if type(str) ~= "string" then
    return nil
  end
  
  local success, result = pcall(vim.json.decode, str)
  if not success then
    return nil
  end
  return result
end

function M.generate_uuid()
  return vim.fn.system("uuidgen"):gsub("\n", "")
end

function M.get_priority_string(priority)
  if priority then
    local display_priority = 5 - priority  -- Convert Todoist priority to display priority
    if display_priority >= 1 and display_priority <= 3 then
      return string.format("[P%d] ", display_priority)
    end
  end
  return ""
end

function M.get_due_string(item)
  if not item.due then
    return ""
  end
  
  if type(item.due) == "table" and type(item.due.string) == "string" then
    return " (Due: " .. item.due.string .. ")"
  end
  
  return ""
end

return M
