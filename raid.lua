local api = require("api")

local Raid = {}
local logger = nil
local elapsed = 0
local intervalMs = 5 * 60 * 1000  -- 5 minutes

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

-- Build a member record for a unit string ("player", "team1".."team50").
-- Returns nil when the unit slot is empty.
local function unitMember(unit)
  local id = safeCall(function() return api.Unit:GetUnitId(unit) end)
  if id == nil or id == 0 then return nil end
  local info = safeCall(function() return api.Unit:GetUnitInfoById(id) end)
  local gs = safeCall(function() return api.Unit:UnitGearScore(unit) end)
  return {
    unit = unit,
    name = info and info.name or nil,
    className = info and (info.className or info.class) or nil,
    level = info and info.level or nil,
    gearScore = tonumber(gs),
    expeditionName = info and info.expeditionName or nil,
    faction = info and info.faction or nil
  }
end

-- Enumerate the player plus team1..team50. Appends with #t+1 so the
-- serializer emits a JSON array.
local function enumerateMembers()
  local members = {}
  local me = unitMember("player")
  if me ~= nil then members[#members + 1] = me end
  for i = 1, 50 do
    local m = unitMember("team" .. i)
    if m ~= nil then members[#members + 1] = m end
  end
  return members
end

function Raid.Init(activeLogger)
  logger = activeLogger
  elapsed = intervalMs
end

function Raid.Snapshot(reason)
  if logger == nil then return end

  local members = enumerateMembers()
  logger.Event("raid_snapshot", {
    schemaVersion = 3,
    reason = reason or "interval",
    isRaid = safeCall(function() return api.Team:IsPartyRaid() end) == true,
    isParty = safeCall(function() return api.Team:IsPartyTeam() end) == true,
    memberCount = #members,
    members = members
  })
end

-- Snapshot immediately when the party/raid roster changes, in addition to
-- the 5-minute cadence (does not reset the interval timer).
function Raid.OnTeamChanged()
  Raid.Snapshot("team_changed")
end

function Raid.Update(dt)
  elapsed = elapsed + dt
  if elapsed < intervalMs then return end
  elapsed = 0
  Raid.Snapshot("interval")
end

return Raid
