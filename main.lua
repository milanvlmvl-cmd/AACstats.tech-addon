local api = require("api")
local Logger = require("AACstats/logger")
local Combat = require("AACstats/combat")
local Gear = require("AACstats/gear")
local Raid = require("AACstats/raid")
local Buffs = require("AACstats/buffs")
local Economy = require("AACstats/economy")
local Guild = require("AACstats/guild")

local AACstats = {
  name = "AACstats.tech",
  author = "Wasbeerotb",
  version = "0.2.0",
  desc = "Silently logs ArcheAge Classic progression data for AACstats.tech."
}

local wnd = nil
local updateElapsed = 0

-- The window is never shown. It exists only as the hidden sink that receives
-- the combat/death/target game events (those are delivered via a widget's
-- OnEvent handler). No visible drawables are created, so tracking is invisible.
local function CreateEventSink()
  wnd = api.Interface:CreateEmptyWindow("AACstatsEventSink", "UIParent")
  wnd:SetExtent(1, 1)
  wnd:AddAnchor("TOPLEFT", "UIParent", 0, 0)

  function wnd:OnEvent(event, ...)
    if event == "COMBAT_MSG" or event == "COMBAT_TEXT" then
      Combat.HandleCombatMessage(...)
    elseif event == "UNIT_DEAD" then
      Combat.HandleUnitDead(...)
    elseif event == "TARGET_CHANGED" then
      Combat.HandleTargetChanged()
    end
  end

  wnd:SetHandler("OnEvent", wnd.OnEvent)
  wnd:RegisterEvent("COMBAT_MSG")
  wnd:RegisterEvent("COMBAT_TEXT")
  wnd:RegisterEvent("UNIT_DEAD")
  wnd:RegisterEvent("TARGET_CHANGED")
  wnd:Show(false)
end

local function OnUpdate(dt)
  updateElapsed = updateElapsed + dt
  if updateElapsed < 250 then return end
  local tick = updateElapsed
  updateElapsed = 0

  Logger.Update(tick)
  Gear.Update(tick)
  Raid.Update(tick)
  Buffs.Update(tick)
  Economy.Update(tick)
  Guild.Update(tick)
end

local function OnLoad()
  math.randomseed(api.Time:GetUiMsec())
  Logger.Start()
  Combat.Init(Logger)
  Gear.Init(Logger)
  Raid.Init(Logger)
  Buffs.Init(Logger)
  Economy.Init(Logger)
  Guild.Init(Logger)
  CreateEventSink()
  Gear.Snapshot("session_start")
  Raid.Snapshot("session_start")
  Economy.Snapshot("session_start")
  Guild.Snapshot("session_start")
  api.On("UPDATE", OnUpdate)
  api.On("TEAM_MEMBERS_CHANGED", Raid.OnTeamChanged)
  api.Log:Info("AACstats.tech tracking started")
end

local function OnUnload()
  api.On("UPDATE", function() return end)
  api.On("TEAM_MEMBERS_CHANGED", function() return end)
  Logger.Stop()

  if wnd ~= nil then
    wnd:Show(false)
    wnd:ReleaseHandler("OnEvent")
    api.Interface:Free(wnd)
    wnd = nil
  end
end

AACstats.OnLoad = OnLoad
AACstats.OnUnload = OnUnload

return AACstats
