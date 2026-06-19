local Serializer = {}

local function escapeString(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub("\"", "\\\"")
  value = value:gsub("\n", "\\n")
  value = value:gsub("\r", "\\r")
  value = value:gsub("\t", "\\t")
  return "\"" .. value .. "\""
end

local function isArray(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" then return false end
    if key > count then count = key end
  end
  for index = 1, count do
    if value[index] == nil then return false end
  end
  return true
end

function Serializer.Encode(value)
  local valueType = type(value)

  if valueType == "nil" then
    return "null"
  end

  if valueType == "boolean" then
    return value and "true" or "false"
  end

  if valueType == "number" then
    return tostring(value)
  end

  if valueType == "string" then
    return escapeString(value)
  end

  if valueType ~= "table" then
    return escapeString(tostring(value))
  end

  local parts = {}
  if isArray(value) then
    for index = 1, #value do
      parts[#parts + 1] = Serializer.Encode(value[index])
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end

  for key, item in pairs(value) do
    parts[#parts + 1] = escapeString(key) .. ":" .. Serializer.Encode(item)
  end

  return "{" .. table.concat(parts, ",") .. "}"
end

return Serializer
