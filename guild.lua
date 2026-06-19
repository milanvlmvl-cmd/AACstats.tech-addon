local api = require("api")

-- Detects the player's guild (ArcheAge "expedition") on session start and every
-- 4 hours, so the website can offer guild opt-in / guild pages. The expedition
-- name + faction come from the unit info table (same source the `numbers` addon
-- uses: unitInfo.expeditionName / unitInfo.faction).
local Guild = {}
local logger = nil
local elapsed = 0
local intervalMs = 4 * 60 * 60 * 1000

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

local function playerInfo()
  return safeCall(function()
    local id = api.Unit:GetUnitId("player")
    return api.Unit:GetUnitInfoById(id)
  end)
end

function Guild.Init(activeLogger)
  logger = activeLogger
  elapsed = intervalMs   -- fire immediately on the first Update tick
end

function Guild.Snapshot(reason)
  if logger == nil then return end
  local info = playerInfo()
  logger.Event("guild_snapshot", {
    schemaVersion = 3,
    reason = reason or "interval",
    expeditionName = info and info.expeditionName or nil,
    faction = info and info.faction or nil
  })
end

function Guild.Update(dt)
  elapsed = elapsed + dt
  if elapsed < intervalMs then return end
  elapsed = 0
  Guild.Snapshot("interval")
end

return Guild
