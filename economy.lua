local api = require("api")

-- Logs the player's gold balance on a fixed interval (and on session start).
-- Carried + bank currency are copper integers; the website divides by 10000.
local Economy = {}
local logger = nil
local elapsed = 0
local intervalMs = 15 * 60 * 1000

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

function Economy.Init(activeLogger)
  logger = activeLogger
  elapsed = intervalMs   -- fire immediately on the first Update tick
end

function Economy.Snapshot(reason)
  if logger == nil then return end
  logger.Event("economy_snapshot", {
    schemaVersion = 3,
    reason = reason or "interval",
    gold = safeCall(function() return api.Bag:GetCurrency() end),
    bankGold = safeCall(function() return api.Bank:GetCurrency() end)
  })
end

function Economy.Update(dt)
  elapsed = elapsed + dt
  if elapsed < intervalMs then return end
  elapsed = 0
  Economy.Snapshot("interval")
end

return Economy
