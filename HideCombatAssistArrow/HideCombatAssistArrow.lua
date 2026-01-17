-- HideCombatAssistArrow
-- Makes Blizzard's AssistedCombatRotationFrame effectively invisible & non-interactive.
-- Safe in and out of combat (alpha/mouse changes are not restricted).

local TARGET_FRAME_NAMES = {
  "AssistedCombatRotationFrame",   -- legacy simple name
  "AssistedTargetingFrame",        -- Blizzard alt name
}

local ASSIST_CHILD_NAME_SEGMENTS = {
  "AssistedCombatRotationFrame",
  "AssistCombatRotationFrame",
  "AssistedTargetingFrame",
}

local ACTION_BUTTON_FAMILIES = {
  { prefix = "ActionButton", count = 12 },
  { prefix = "MultiBarBottomLeftButton", count = 12 },
  { prefix = "MultiBarBottomLeftActionButton", count = 12 },
  { prefix = "MultiBarBottomRightButton", count = 12 },
  { prefix = "MultiBarBottomRightActionButton", count = 12 },
  { prefix = "MultiBarRightButton", count = 12 },
  { prefix = "MultiBarLeftButton", count = 12 },
  { prefix = "MultiBar5Button", count = 12 },
  { prefix = "MultiBar6Button", count = 12 },
  { prefix = "MultiBar7Button", count = 12 },
  { prefix = "MultiBar8Button", count = 12 },
  { prefix = "MultiBar9Button", count = 12 },
  { prefix = "MultiBar10Button", count = 12 },
  { prefix = "MultiBar11Button", count = 12 },
  { prefix = "MultiBar12Button", count = 12 },
  { prefix = "OverrideActionBarButton", count = 6 },
  { prefix = "PossessButton", count = 2 },
  { prefix = "StanceButton", count = 10 },
  { prefix = "PetActionButton", count = 10 },
  { prefix = "DominosActionButton", count = 120 },
  { prefix = "DominosClassButton", count = 20 },
  { prefix = "DominosPetButton", count = 10 },
  { prefix = "DominosPossessButton", count = 10 },
  { prefix = "BT4Button", count = 180 },
  { prefix = "BT4PetButton", count = 10 },
  { prefix = "BT4StanceButton", count = 10 },
  { prefix = "BT4ClassButton", count = 20 },
}

local function log(msg)
  pcall(print, ("HideAssistedCombatRotation: %s"):format(msg))
end

local function neutralizeFrame(f)
  if not f or (type(f) ~= "table" and type(f) ~= "userdata") then return end
  -- Visual invisibility + no clicks
  if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
  -- If Blizzard re-shows it, keep it invisible.
  if f.Show and not f._HideACR_hooked then
    f._HideACR_hooked = true
    hooksecurefunc(f, "Show", function(self)
      if self.SetAlpha then self:SetAlpha(0) end
    end)
  end
end

local function safeGetFrameName(frame)
  local ok, name = pcall(function()
    return frame.GetName and frame:GetName()
  end)
  if ok and name and name ~= "" then
    return name
  end
end

local function frameNameMatchesAssist(frameName, parentName)
  if not frameName then return false end
  for _, segment in ipairs(ASSIST_CHILD_NAME_SEGMENTS) do
    if frameName:find(segment, 1, true) then
      if not parentName or frameName:find(parentName, 1, true) or frameName == segment then
        return true
      end
    end
  end
  return false
end

local function scanParentForAssistChild(parent, parentName)
  if not parent then return false end
  parentName = parentName or safeGetFrameName(parent)
  local found = false

  -- Check for direct keyed children first (parent.AssistedCombatRotationFrame, etc).
  for _, segment in ipairs(ASSIST_CHILD_NAME_SEGMENTS) do
    local child = parent[segment]
    if child then
      local childName = safeGetFrameName(child) or (parentName and (parentName .. segment))
      neutralizeFrame(child)
      found = true
    end
  end

  if parent.GetChildren then
    local children = { parent:GetChildren() }
    for _, child in ipairs(children) do
      local childName = safeGetFrameName(child)
      if frameNameMatchesAssist(childName, parentName) then
        neutralizeFrame(child)
        found = true
      end
    end
  end

  return found
end

local function findAndNeutralize()
  local found = false
  for _, name in ipairs(TARGET_FRAME_NAMES) do
    local f = _G[name]
    if f then
      neutralizeFrame(f)
      found = true
    end
  end

  for _, family in ipairs(ACTION_BUTTON_FAMILIES) do
    for index = 1, family.count do
      local parentName = family.prefix .. index
      local parent = _G[parentName]
      if parent then
        if scanParentForAssistChild(parent, parentName) then
          found = true
        end
      end
    end
  end

  return found
end

-- Kick off after login, and retry a few times in case the frame spawns late.
local driver = CreateFrame("Frame")
local EVENTS = {
  "PLAYER_LOGIN",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED",
  "SPELLS_CHANGED",
  "ACTIONBAR_SLOT_CHANGED",
  "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_OVERRIDE_ACTIONBAR",
  "UPDATE_POSSESS_BAR",
  "PET_BAR_UPDATE",
  "PET_BAR_HIDEGRID",
  "PET_BAR_SHOWGRID",
  "PLAYER_TALENT_UPDATE",
}
for _, event in ipairs(EVENTS) do
  driver:RegisterEvent(event)
end

local tickInProgress = false
local pendingTicker = nil

local function startRetryLoop()
  if tickInProgress then return end
  tickInProgress = true

  local attempts, maxAttempts = 0, 30
  pendingTicker = C_Timer.NewTicker(0.5, function(ticker)
    attempts = attempts + 1
    local got = findAndNeutralize()
    if got or attempts >= maxAttempts then
      if ticker then
        ticker:Cancel()
      end
      pendingTicker = nil
      tickInProgress = false
    end
  end)
end

driver:SetScript("OnEvent", function()
  if pendingTicker == nil and tickInProgress then
    -- Safety: reset if ticker cleared unexpectedly.
    tickInProgress = false
  end
  if pendingTicker == nil then
    startRetryLoop()
  end
end)

-- Also periodically reapply in long sessions in case the UI rebuilds.
C_Timer.NewTicker(60, function()
  findAndNeutralize()
end)

