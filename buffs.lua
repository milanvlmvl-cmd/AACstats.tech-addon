local api = require("api")

local Buffs = {}
local logger = nil
local elapsed = 0
local intervalMs = 5000
local known = {}

local function snapshotPlayerBuffs()
  local buffs = {}
  local ok, playerId = pcall(function() return api.Unit:GetUnitId("player") end)
  if not ok or playerId == nil then return buffs end

  local countOk, count = pcall(function() return api.Unit:UnitBuffCount(playerId) end)
  if not countOk or count == nil then return buffs end

  for index = 1, count do
    local buffOk, buff = pcall(function() return api.Unit:UnitBuff(playerId, index) end)
    if buffOk and buff ~= nil then
      local name = buff.name or buff.buffName or tostring(index)
      buffs[tostring(name)] = {
        buffName = tostring(name),
        stack = buff.stack or buff.stackCount or buff.count,
        durationMs = buff.duration or buff.durationMs,
        remainingMs = buff.remaining or buff.remainingMs or buff.timeLeft,
        sourceName = buff.sourceName or buff.casterName
      }
    end
  end

  return buffs
end

function Buffs.Init(activeLogger)
  logger = activeLogger
  elapsed = intervalMs
  known = {}
end

function Buffs.Update(dt)
  elapsed = elapsed + dt
  if elapsed < intervalMs then return end
  elapsed = 0
  if logger == nil then return end

  local current = snapshotPlayerBuffs()

  for name, _ in pairs(current) do
    if known[name] == nil then
      logger.Event("buff_applied", {
        schemaVersion = 2,
        unitName = "player",
        buffName = name,
        stack = current[name].stack,
        durationMs = current[name].durationMs,
        remainingMs = current[name].remainingMs,
        sourceName = current[name].sourceName
      })
    end
  end

  for name, _ in pairs(known) do
    if current[name] == nil then
      logger.Event("buff_removed", {
        schemaVersion = 2,
        unitName = "player",
        buffName = name,
        stack = known[name].stack,
        durationMs = known[name].durationMs,
        remainingMs = known[name].remainingMs,
        sourceName = known[name].sourceName
      })
    end
  end

  known = current
end

return Buffs
