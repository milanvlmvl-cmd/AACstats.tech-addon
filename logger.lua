local api = require("api")
local Serializer = require("AACstats/serializer")

local Logger = {}

local sessionId = nil
local filePath = nil
local buffer = {}
local flushIntervalMs = 10000
local elapsedSinceFlush = 0

local function nowIso()
  local localTime = api.Time:GetLocalTime()
  if type(localTime) == "table" then
    local year = localTime.year or localTime.y or 1970
    local month = localTime.month or localTime.mon or 1
    local day = localTime.day or localTime.d or 1
    local hour = localTime.hour or localTime.h or 0
    local min = localTime.minute or localTime.min or 0
    local sec = localTime.second or localTime.sec or 0
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, min, sec)
  end
  return tostring(localTime or api.Time:GetUiMsec())
end

local function makeSessionId()
  return "aac-" .. tostring(api.Time:GetUiMsec()) .. "-" .. tostring(math.random(100000, 999999))
end

local function makeFilePath(id)
  return "AACstats/logs/session_" .. id .. ".jsonl"
end

function Logger.Start()
  sessionId = makeSessionId()
  filePath = makeFilePath(sessionId)
  buffer = {}
  elapsedSinceFlush = 0
  api.File:Write(filePath, "")
  Logger.Event("session_start", {
    addon = "ProgressionTracker",
    version = "0.2.0"
  })
  Logger.Flush()
end

function Logger.SessionId()
  return sessionId
end

function Logger.FilePath()
  return filePath
end

function Logger.Event(eventType, payload)
  if sessionId == nil then return end

  local record = {
    schemaVersion = 3,
    sessionId = sessionId,
    eventType = eventType,
    occurredAtMs = api.Time:GetUiMsec(),
    localTime = nowIso(),
    payload = payload or {}
  }

  buffer[#buffer + 1] = Serializer.Encode(record)

  if #buffer >= 100 then
    Logger.Flush()
  end
end

function Logger.Update(dt)
  elapsedSinceFlush = elapsedSinceFlush + dt
  if elapsedSinceFlush >= flushIntervalMs then
    elapsedSinceFlush = 0
    Logger.Flush()
  end
end

function Logger.Flush()
  if filePath == nil or #buffer == 0 then return end
  local existing = api.File:Read(filePath) or ""
  api.File:Write(filePath, existing .. table.concat(buffer, "\n") .. "\n")
  buffer = {}
end

function Logger.Stop()
  Logger.Event("session_end", {})
  Logger.Flush()
end

return Logger
