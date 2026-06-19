local api = require("api")

local Gear = {}
local logger = nil
local elapsed = 0
local snapshotIntervalMs = 30 * 60 * 1000

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

-- Equipment slots to read, mirroring darugear_exporter's slot set.
local GEAR_SLOTS = {
  EQUIP_SLOT.HEAD, EQUIP_SLOT.NECK, EQUIP_SLOT.CHEST, EQUIP_SLOT.WAIST,
  EQUIP_SLOT.HANDS, EQUIP_SLOT.LEGS, EQUIP_SLOT.ARMS, EQUIP_SLOT.FEET,
  EQUIP_SLOT.EAR_1, EQUIP_SLOT.EAR_2, EQUIP_SLOT.BACK,
  EQUIP_SLOT.FINGER_1, EQUIP_SLOT.FINGER_2,
  EQUIP_SLOT.UNDERSHIRT, EQUIP_SLOT.UNDERPANTS,
  EQUIP_SLOT.MAINHAND, EQUIP_SLOT.OFFHAND, EQUIP_SLOT.RANGED,
  EQUIP_SLOT.MUSICAL, EQUIP_SLOT.BACKPACK, EQUIP_SLOT.COSPLAY
}

local function playerInfo()
  return safeCall(function()
    local playerId = api.Unit:GetUnitId("player")
    return api.Unit:GetUnitInfoById(playerId)
  end)
end

local function playerName()
  local info = playerInfo()
  return info and info.name or nil
end

-- UnitGearScore expects a unit STRING ("player"/"team1"), not a unit id.
local function playerGearScore()
  return safeCall(function()
    return api.Unit:UnitGearScore("player")
  end)
end

-- Read each equipped slot via the documented two-arg tooltip API and the
-- structured info API, building a proper Lua array of per-slot records.
local function equipmentSnapshot()
  local equipment = {}
  for _, slot in ipairs(GEAR_SLOTS) do
    local info = safeCall(function()
      return api.Equipment:GetEquippedItemTooltipInfo(slot)
    end)
    local text = safeCall(function()
      return api.Equipment:GetEquippedItemTooltipText("player", slot)
    end)
    if info ~= nil or text ~= nil then
      local rec = { slot = slot }
      if type(info) == "table" then
        rec.name = info.name or info.itemName
        rec.itemGrade = info.itemGrade or info.grade
        rec.level = info.level or info.itemLevel
        rec.gearScore = info.gearScore or info.gs
      end
      if text ~= nil then rec.text = tostring(text) end
      equipment[#equipment + 1] = rec
    end
  end
  return equipment
end

-- Fallback numeric score when UnitGearScore is unavailable: sum whatever
-- per-item magnitude we could read (gear score, then grade, then level).
local function derivedGearScore(equipment)
  local total = 0
  local counted = false
  for _, rec in ipairs(equipment) do
    local v = tonumber(rec.gearScore) or tonumber(rec.itemGrade) or tonumber(rec.level)
    if v ~= nil then
      total = total + v
      counted = true
    end
  end
  if counted then return total end
  return nil
end

-- statSnapshot kept as-is: GetUnitStat/UnitStat are not in the documented API
-- and return nil, so this remains an empty table (serialized as []).
local function statSnapshot()
  return {}
end

function Gear.Init(activeLogger)
  logger = activeLogger
  elapsed = snapshotIntervalMs
end

function Gear.Snapshot(reason)
  if logger == nil then return end

  local info = playerInfo()
  local equipment = equipmentSnapshot()

  local gs = playerGearScore()
  local source = "unitGearScore"
  if tonumber(gs) == nil then
    gs = derivedGearScore(equipment)
    source = (gs ~= nil) and "derived" or "none"
  end

  logger.Event("gear_snapshot", {
    schemaVersion = 3,
    reason = reason or "interval",
    characterName = (info and info.name) or playerName(),
    className = info and (info.className or info.class) or nil,
    level = info and info.level or nil,
    gearScore = tonumber(gs),
    gearScoreSource = source,
    stats = statSnapshot(),
    equipment = equipment
  })
end

function Gear.Update(dt)
  elapsed = elapsed + dt
  if elapsed < snapshotIntervalMs then return end
  elapsed = 0
  Gear.Snapshot("interval")
end

return Gear
