local api = require("api")

local Combat = {}
local logger = nil
local knownEntityNamesById = {}

local function safeString(value)
  if value == nil then return nil end
  return tostring(value)
end

local function safeNumber(value)
  local number = tonumber(value)
  if number == nil then return nil end
  if number < 0 then return -number end
  return number
end

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

local function playerName()
  return safeCall(function()
    local playerId = api.Unit:GetUnitId("player")
    return api.Unit:GetUnitNameById(playerId)
  end)
end

local function setKnownName(id, name)
  if id ~= nil and name ~= nil then
    knownEntityNamesById[tostring(id)] = tostring(name)
  end
end

local function classifyScope(payload)
  local sourceType = tostring(payload.sourceType or "")
  local targetType = tostring(payload.targetType or "")
  if sourceType == "player" and targetType == "player" then
    payload.combatScopeConfidence = "confirmed"
    return "pvp"
  end
  if sourceType == "player" or targetType == "player" then
    if sourceType == "npc" or targetType == "npc" or sourceType == "object" or targetType == "object" then
      payload.combatScopeConfidence = "confirmed"
      return "pve"
    end
  end
  payload.combatScopeConfidence = "unknown"
  return "unknown"
end

local function commonPayload(raw, eventKind)
  return {
    raw = raw,
    eventKind = eventKind,
    schemaVersion = 2
  }
end

local function parseRawCombat(args)
  local raw = {}
  for index = 1, #args do
    raw[tostring(index)] = safeString(args[index])
  end

  local rawType = safeString(args[2])
  local payload = commonPayload(raw, "damage")
  local eventType = "combat_damage"

  if rawType == "SPELL_DAMAGE" or rawType == "SPELL_DOT_DAMAGE" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = safeString(args[6])
    payload.damageType = safeString(args[7])
    payload.amount = safeNumber(args[8])
    payload.resourceType = safeString(args[9])
    payload.result = safeString(args[10])
    payload.eventKind = "damage"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "MELEE_DAMAGE" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = "Melee"
    payload.amount = safeNumber(args[5])
    payload.resourceType = safeString(args[6])
    payload.result = safeString(args[7])
    payload.eventKind = "damage"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "ENVIRONMENTAL_DAMAGE" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = safeString(args[5])
    payload.amount = safeNumber(args[7])
    payload.resourceType = safeString(args[8])
    payload.result = safeString(args[9])
    payload.eventKind = "damage"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "SPELL_HEALED" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = safeString(args[6])
    payload.damageType = safeString(args[7])
    payload.amount = safeNumber(args[8])
    payload.result = safeString(args[9])
    payload.eventKind = "heal"
    eventType = "combat_heal"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "SPELL_ENERGIZE" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = safeString(args[6])
    payload.damageType = safeString(args[7])
    payload.amount = safeNumber(args[8])
    payload.resourceType = safeString(args[9])
    payload.eventKind = "resource"
    eventType = "combat_resource"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "SPELL_MISSED" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = safeString(args[6])
    payload.damageType = safeString(args[7])
    payload.result = safeString(args[8])
    payload.amount = 0
    payload.eventKind = "miss"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif rawType == "MELEE_MISSED" then
    payload.targetEntityId = safeString(args[1])
    payload.sourceName = safeString(args[3])
    payload.targetName = safeString(args[4])
    payload.skillName = "Melee"
    payload.result = safeString(args[5])
    payload.amount = 0
    payload.eventKind = "miss"
    setKnownName(payload.targetEntityId, payload.targetName)
  elseif args[4] == "SKILL" or args[4] == "SWING" or args[4] == "DOT" or args[4] == "HEAL" or args[4] == "MANA" then
    payload.sourceEntityId = safeString(args[1])
    payload.targetEntityId = safeString(args[2])
    payload.sourceName = knownEntityNamesById[payload.sourceEntityId]
    payload.targetName = knownEntityNamesById[payload.targetEntityId]
    payload.skillName = safeString(args[4])
    payload.amount = safeNumber(args[3])
    payload.result = safeString(args[5])
    payload.pairedDetail = true
    if args[4] == "HEAL" then
      payload.eventKind = "heal"
      eventType = "combat_heal"
    elseif args[4] == "MANA" then
      payload.eventKind = "resource"
      eventType = "combat_resource"
    end
  else
    payload.message = safeString(args[1])
    payload.combatScope = "unknown"
    payload.combatScopeConfidence = "unknown"
    return eventType, payload
  end

  payload.playerName = playerName()
  payload.combatScope = classifyScope(payload)
  return eventType, payload
end

function Combat.Init(activeLogger)
  logger = activeLogger
  knownEntityNamesById = {}
end

function Combat.HandleCombatMessage(...)
  if logger == nil then return end
  local args = { ... }
  local eventType, payload = parseRawCombat(args)

  local parsed = nil
  if ParseCombatMessage ~= nil then
    local ok, result = pcall(ParseCombatMessage, unpack(args))
    if ok then parsed = result end
  end

  if type(parsed) == "table" then
    payload.sourceName = parsed.sourceName or parsed.attacker or parsed.source or payload.sourceName
    payload.targetName = parsed.targetName or parsed.victim or parsed.target or payload.targetName
    payload.skillName = parsed.skillName or parsed.skill or parsed.ability or payload.skillName
    payload.amount = safeNumber(parsed.amount or parsed.damage or parsed.heal) or payload.amount
    payload.sourceType = parsed.sourceType or payload.sourceType
    payload.targetType = parsed.targetType or payload.targetType
    payload.sourceEntityId = parsed.sourceEntityId or parsed.sourceId or payload.sourceEntityId
    payload.targetEntityId = parsed.targetEntityId or parsed.targetId or payload.targetEntityId
    payload.result = parsed.result or payload.result
    payload.resourceType = parsed.resourceType or payload.resourceType
    payload.combatScope = parsed.combatScope or classifyScope(payload)
  end

  logger.Event(eventType, payload)
end

function Combat.HandleUnitDead(...)
  if logger == nil then return end
  local args = { ... }
  local payload = {
    raw = {},
    schemaVersion = 2,
    eventKind = "death",
    combatScope = "unknown",
    combatScopeConfidence = "unknown",
    targetEntityId = safeString(args[1]),
    targetName = knownEntityNamesById[safeString(args[1]) or ""]
  }
  for index = 1, #args do
    payload.raw[tostring(index)] = safeString(args[index])
  end
  logger.Event("combat_death", payload)
end

function Combat.HandleTargetChanged()
  if logger == nil then return end
  local payload = {
    schemaVersion = 2
  }
  local ok, targetId = pcall(function() return api.Unit:GetUnitId("target") end)
  if ok and targetId ~= nil then
    payload.targetEntityId = safeString(targetId)
    payload.targetName = safeString(api.Unit:GetUnitNameById(targetId))
    setKnownName(payload.targetEntityId, payload.targetName)

    local gearOk, gearScore = pcall(function() return api.Unit:UnitGearScore(targetId) end)
    if gearOk then payload.targetGearScore = gearScore end

    local classOk, className = pcall(function() return api.Ability:GetUnitClassName(targetId) end)
    if classOk then payload.targetClassName = className end

    payload.targetIsPlayer = safeCall(function() return api.Unit:IsPlayer(targetId) end)
    payload.targetType = safeCall(function() return api.Unit:GetUnitType(targetId) end)
    payload.targetFaction = safeCall(function() return api.Unit:GetFactionName(targetId) end)
  end
  logger.Event("target_snapshot", payload)
end

return Combat
