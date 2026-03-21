--- @class ProfileData
--- @field profile_path string
--- @field list table<string, RoutineAnnotation[]>  keyed by absolute file path
--- @field top TopEntry[]
--- @field total_str string

local M = {}

local _data = nil

--- Store profile data.
--- @param data ProfileData
function M.set(data)
  _data = data
end

--- Get current profile data, or nil if not loaded.
--- @return ProfileData|nil
function M.get()
  return _data
end

--- Get annotations for a specific file path.
--- @param filepath string
--- @return RoutineAnnotation[]|nil
function M.get_file(filepath)
  if _data == nil or _data.list == nil then
    return nil
  end
  return _data.list[filepath]
end

--- Clear all cached data.
function M.clear()
  _data = nil
end

--- Check if profile data is loaded.
--- @return boolean
function M.is_loaded()
  return _data ~= nil
end

return M
