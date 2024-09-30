local raidleadtinypad = RaidLeadTinyPad

local current = 1 -- current page being viewed

RaidLeadTinyPadPages = {} -- the pages for RaidLeadTinyPad are in a numerically indexed table of tables of strings
RaidLeadTinyPadPageLevels = {} -- a table of numeric levels for bookmarks of pages.
--Currently just two levels, and all the second level does is indent a bit.
RaidLeadTinyPadPageMobs = {} -- mobs; tartetting them triggers pages
RaidLeadTinyPadSettings = {} -- settings (Locked, Font)
local pages, settings, levels, mobs -- will assign these in PLAYER_LOGIN after savedvars load
local undoPage -- the original contents of a page to undo to
local InCombat -- Boolean, combat statuts
local SnoozeStartTime -- Time that snooze was pushed; initialized to current time minus SnoozeDuration
local SnoozeDuration = 5 -- Number of minutes Snooze will be effective
local SnoozeDurationTicks -- Representation of SnoozeDuration in ticks.  Not set here, calculated from SnoozeDuration.

-- list of fonts to cycle through
RaidLeadTinyPad.fonts = {
	{"Fonts\\FRIZQT__.TTF",10},
	{"Fonts\\FRIZQT__.TTF",12}, -- default
	{"Fonts\\FRIZQT__.TTF",16},
	{"Fonts\\ARIALN.TTF",12},
	{"Fonts\\ARIALN.TTF",16},
	{"Fonts\\ARIALN.TTF",20},
	{"Fonts\\MORPHEUS.ttf",16,"OUTLINE"},
	{"Fonts\\MORPHEUS.ttf",24,"OUTLINE"},
	-- add fonts here
}

-- key binding interface constants
BINDING_HEADER_TINYPAD = "RaidLeadTinyPad"
BINDING_NAME_TINYPAD_TOGGLE = "Show/Hide RaidLeadTinyPad"
BINDING_NAME_TINYPAD_SEARCH = "Search within RaidLeadTinyPad"

function raidleadtinypad:PLAYER_LOGIN()
	--print("In RaidLeadTinyPad PLAYER_LOGIN")
--RaidLeadTinyPadBookmarks:IsVisible() and "RaidLeadTinyPadBookmarks"
	-- savedvars
	pages = RaidLeadTinyPadPages
    levels = RaidLeadTinyPadPageLevels
    mobs = RaidLeadTinyPadPageMobs
	settings = RaidLeadTinyPadSettings
	settings.Font = settings.Font or 2
	InCombat = false

	-- slash command stuff
	SlashCmdList["RAIDLEADTINYPAD"] = RaidLeadTinyPad.SlashHandler
	SLASH_RAIDLEADTINYPAD1 = "/rlpad"
	SLASH_RAIDLEADTINYPAD2 = "/raidleadtinypad"

	-- setup the rest
	raidleadtinypad:ApplyBackdrop()
	RaidLeadTinyPadEditBox:SetHyperlinksEnabled(true)
	self:SetResizeBounds(217,96)
	raidleadtinypad:UpdateLock()
	raidleadtinypad:UpdateFont()
	
	--RaidLeadTinyPad:Show()

	-- attach tooltip and OnClicks to each titlebar/search button
  -- No longer using these four, commenting out.
--		["first"] = {"First Page","Go to the first page\n\n\124cFFA5A5A5Hold Shift to move this page to the first page.",RaidLeadTinyPad.FirstPage},
--		["previous"] = {"Previous","Go to previous page.\n\n\124cFFA5A5A5Hold Shift to move this page back one page.",RaidLeadTinyPad.PreviousPage},
--		["next"] = {"Next","Go to next page.\n\n\124cFFA5A5A5Hold Shift to move this page forward one page.",RaidLeadTinyPad.NextPage},
--		["last"] = {"Last Page","Go to the last page.\n\n\124cFFA5A5A5Hold Shift to move this page to the last page.",RaidLeadTinyPad.LastPage},
	for key,info in pairs({
		["close"] = {"Close","RaidLeadTinyPad version "..C_AddOns.GetAddOnMetadata("RaidLeadTinyPad","Version"),RaidLeadTinyPad.Toggle},
		["new"] = {"New","Add a new page after the current page.",RaidLeadTinyPad.NewPage},
		["newsub"] = {"New Subpage","Add a new sub-page after the current page.",RaidLeadTinyPad.NewSubPage},
		["indenttoggle"] = {"Toggle Indention","Toggles indention of the current page.",RaidLeadTinyPad.ToggleIndent},
		["linkmob"] = {"Link Mob","Links a mob to the current page.",RaidLeadTinyPad.LinkMob},
		["showbookmarks"] = {"Bookmarks","Shows and hides the bookmark panel.",RaidLeadTinyPad.ToggleBookmarks},
		["snooze"] = {"Snooze","Prevents this window from appearing for 5 minutes.",RaidLeadTinyPad.Snooze},
		["delete"] = {"Delete","Permanently remove this page.\n\n\124cFFA5A5A5Hold Shift to delete without confirmation.",RaidLeadTinyPad.DeletePage },
		["undo"] = {"Undo","Revert this page to last saved text.",RaidLeadTinyPad.Undo},
		["broadcast"] = {"Broadcast","Broadcast this page to the raid.",RaidLeadTinyPad.Broadcast},
		["config"] = {"Options","Search pages for text, change font or lock window.",RaidLeadTinyPad.ToggleSettingsPanel},
		["settingspanel.find"] = {"Find Next","Find next page with this text.\n\n\124cFFA5A5A5Hold Shift to find last page with this text.",RaidLeadTinyPad.SearchOnEnter},
		["settingspanel.lock"] = {"Lock","Lock or unlock the window, preventing it from being moved or dismissed with the ESCape key.",RaidLeadTinyPad.ToggleLock},
		["settingspanel.font"] = {"Font","Cycle through different fonts.\n\n\124cFFA5A5A5Hold Shift to cycle backwards.",RaidLeadTinyPad.NextFont},
    ["settingspanel.size"] = {"Size","Toggle the size of RaidLeadTinyPad.",RaidLeadTinyPad.ToggleSize},
	}) do
		local parentKey,subKey = key:match("(%w+)%.(%w+)")
		local button = parentKey and raidleadtinypad[parentKey][subKey] or raidleadtinypad[key]
		button.tooltipTitle = info[1]
		button.tooltipBody = info[2]
		if info[3] then
			button:SetScript("OnClick",info[3])
		end
	end

	-- if no pages made yet, create one
	if #pages==0 then
		tinsert(pages,{"", ""})
    tinsert(levels, 1)
    tinsert(mobs, "")
    current = #pages
	end


	--SendChatMessage("Testing RegisterEvents")
	RaidLeadTinyPad:RegisterEvent("PLAYER_LOGOUT")
	--RaidLeadTinyPad:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	RaidLeadTinyPad:RegisterEvent("PLAYER_TARGET_CHANGED")
	RaidLeadTinyPad:RegisterEvent("PLAYER_REGEN_DISABLED") --Used as "entering combat"
	RaidLeadTinyPad:RegisterEvent("PLAYER_REGEN_ENABLED") --Used as "leaving combat"
  
	-- set up chat link hooks
	local old_ChatEdit_InsertLink = ChatEdit_InsertLink
	function ChatEdit_InsertLink(text)
		if RaidLeadTinyPadEditBox:HasFocus() then
			RaidLeadTinyPadEditBox:Insert(text)
			return true -- prevents the stacksplit frame from showing
		else
			return old_ChatEdit_InsertLink(text)
		end
	end
	
	SnoozeDurationTicks = SnoozeDuration * 240
	SnoozeStartTime = GetTime() - SnoozeDurationTicks
end

--Frame checking:
function raidleadtinypadframechecker(frame)
	print("Parent: " ..tostring(frame:GetParent()))
	print("Width: " ..frame:GetWidth()); print("Height: " ..frame:GetHeight())
	print("Framelevel:" ..frame:GetFrameLevel())
	print("Shown:", frame:IsShown())
	print("Point:" ..frame:GetPoint(0))
end

function raidleadtinypad:PLAYER_LOGOUT()
	if RaidLeadTinyPad:IsVisible() then
		raidleadtinypad:SaveCurrentPage()
	end
end

function raidleadtinypad:PLAYER_TARGET_CHANGED()
	local Mobname = GetUnitName("target", false)

	local FoundMob = false
	if Mobname == nil then 
		Mobname = ""
	end

	local time = GetTime()
	local rltpSnoozeTime = (GetTime() - SnoozeStartTime)
	local rltpRaidMemberCount = GetNumGroupMembers()

	if rltpRaidMemberCount > 0 and rltpSnoozeTime > SnoozeDurationTicks then
		if Mobname ~= "" then
			for i=1,#pages do
				if mobs[i] == Mobname then
					current = i
					FoundMob = true
				end
			end

			if FoundMob == true then
				raidleadtinypad:ShowPage(current, (not InCombat))
				--raidleadtinypad:ShowPage(current, false)
			end
		end
	end
end

function raidleadtinypad:PLAYER_REGEN_DISABLED()
	--SendChatMessage("Testing entered combat")
	--Used as "entering combat".
  InCombat = true
  --Disabling the hiding of RLPad during combat.  Not sure how permanent this will be.
  --MUCH later comment: It wasn't permanent, but I DID leave it active the entirety of dragonflight, wishing it didn't do that.
  --InCombat = false
end
function raidleadtinypad:PLAYER_REGEN_ENABLED()
	--SendChatMessage("Testing left combat")
	--Used as "leaving combat"
  InCombat = false
end

-- returns the body of given page number
function raidleadtinypad:GetPageText(page)
	local page = page or current
  return pages[page][2]
end

function raidleadtinypad:GetPageTitleText(page)
	local page = page or current
  return pages[page][1]
end

function raidleadtinypad:Toggle()
	RaidLeadTinyPad:SetShown(not RaidLeadTinyPad:IsVisible())
end

function RaidLeadTinyPad:OnMouseDown()
	if not settings.Lock then
		RaidLeadTinyPad:StartMoving()
	end
end

function RaidLeadTinyPad:OnMouseUp()
	if not settings.Lock then
		RaidLeadTinyPad:StopMovingOrSizing()
	end
end

function RaidLeadTinyPad:OnShow()
	--self:UpdateESCable()
	self:ShowPage(current, true)
	self:UpdateScale()
end

function RaidLeadTinyPad:OnHide()
	raidleadtinypad:SaveCurrentPage()
	RaidLeadTinyPad.settingspanel:Hide()
	--self:UpdateESCable()
end

function RaidLeadTinyPad:OnTextChanged()
   RaidLeadTinyPad.undo:SetEnabled(undoPage~=RaidLeadTinyPadEditBox:GetText())
   raidleadtinypad:SaveCurrentPage()
end

function RaidLeadTinyPad:OnPageTitleTextChanged()
  local rlPageTitle = RaidLeadTinyPadPageTitleEditBox:GetText()
  pages[current][1] = rlPageTitle
  raidleadtinypad:SaveCurrentPage()
  local button = raidleadtinypad:GetBookmarkButton(current)
  button.name:SetText(rlPageTitle)
end

function RaidLeadTinyPad:PageTitleOnEnter()
  local rlPageTitle = RaidLeadTinyPadPageTitleEditBox:GetText()
  if rlPageTitle == "" then
    rlPageTitle = "Page " .. current
    RaidLeadTinyPadPageTitleEditBox:SetText(rlPageTitle)
  end
  RaidLeadTinyPadPageTitleEditBox:ClearFocus()
  pages[current][1] = rlPageTitle
  raidleadtinypad:SaveCurrentPage()
  local button = raidleadtinypad:GetBookmarkButton(current)
  button.name:SetText(rlPageTitle)
end

-- this mimics ScrollingEdit_OnCursorChanged in UIPanelTemplates.lua, but instead
-- of having an always-running OnUpdate, this just turns on the OnUpdate for one frame
function RaidLeadTinyPad:OnCursorChanged(x,y,w,h)
	self.cursorOffset = y
	self.cursorHeight = h
	self.handleCursorChange = true;
	self:SetScript("OnUpdate",RaidLeadTinyPad.OnCursorOnUpdate)
end

-- this is triggered from OnCursorChanged, and immediately shuts down and calls
-- ScrollingEdit_OnUpdate defined in UIPanelTemplates.lua
function RaidLeadTinyPad:OnCursorOnUpdate(elapsed)
	self:SetScript("OnUpdate",nil)
	ScrollingEdit_OnUpdate(self,elapsed,self:GetParent())
end

-- at most only one entry from RaidLeadTinyPad should be in UISpecialFrames, and only when visible:
-- RaidLeadTinyPadBookmarks > RaidLeadTinyPad
-- this will go through UISpecialFrames and ensure only the topmost frame is in the table and remove others
function raidleadtinypad:UpdateESCable()
	local specialFound
	local specialFrame = (RaidLeadTinyPadBookmarks:IsVisible() and "RaidLeadTinyPadBookmarks") or (not settings.Lock and RaidLeadTinyPad:IsVisible() and "RaidLeadTinyPad")
	for i=#UISpecialFrames,1,-1 do
		local frameName = UISpecialFrames[i]
		
		if frameName=="RaidLeadTinyPad" or frameName=="RaidLeadTinyPadBookmarks" then
			if frameName~=specialFrame then
				tremove(UISpecialFrames,i)
			else
				specialFound = true
			end
		end
	end
	if not specialFound and specialFrame then
		tinsert(UISpecialFrames,specialFrame)
	end
end

-- when the window is locked, the border is black, grey when unlocked
function raidleadtinypad:UpdateLock()
	local c = settings.Lock and 0 or .75
	RaidLeadTinyPad:SetBackdropBorderColor(c,c,c)
	RaidLeadTinyPad.settingspanel:SetBackdropBorderColor(c,c,c)
  RaidLeadTinyPadBookmarks:SetBackdropBorderColor(c,c,c)
  RaidLeadTinyPad.PageTitlepanel:SetBackdropBorderColor(c,c,c)
	RaidLeadTinyPad.resize:SetShown(not settings.Lock)
  RaidLeadTinyPadPageTitleEditBox:SetEnabled(not settings.Lock)
  RaidLeadTinyPadEditBox:SetEnabled(not settings.Lock)
end

function raidleadtinypad:UpdateFont()
	RaidLeadTinyPadEditBox:SetFont(unpack(RaidLeadTinyPad.fonts[settings.Font]), 12, "")
end

--[[ titlebar buttons ]]

function raidleadtinypad:SaveCurrentPage()
  pages[current][2] = RaidLeadTinyPadEditBox:GetText()
  pages[current][1] = RaidLeadTinyPadPageTitleEditBox:GetText()
end

function raidleadtinypad:ShowPage(page, rlpadShowNow)
	if rlpadShowNow and (not RaidLeadTinyPad:IsVisible()) then
		RaidLeadTinyPad:Show()
	end
   if page and page>0 and page<=#pages then
		current = page
    RaidLeadTinyPadEditBox:ClearFocus()
		RaidLeadTinyPadEditBox:SetText(raidleadtinypad:GetPageText())
		RaidLeadTinyPadPageTitleEditBox:SetText(raidleadtinypad:GetPageTitleText())
		RaidLeadTinyPadEditBox:SetCursorPosition(0)
    undoPage = raidleadtinypad:GetPageText()
	end
  raidleadtinypad:UpdateBookmarks()
end

function raidleadtinypad:NewPage()
	raidleadtinypad:SaveCurrentPage()
  tinsert(pages,current+1,{"", ""})
  tinsert(levels,current+1,1)
  tinsert(mobs,current+1,"")
  raidleadtinypad:ShowPage(current+1, true)
end

function raidleadtinypad:NewSubPage()
	raidleadtinypad:SaveCurrentPage()
  tinsert(pages,current+1,{"", ""})
  tinsert(levels,current+1,2)
  tinsert(mobs,current+1,"")
  raidleadtinypad:ShowPage(current+1, true)
end

function raidleadtinypad:LinkMob()
  local Mobname = GetUnitName("target", false)
  if Mobname == nil then 
    Mobname = ""
  end
  mobs[current] = Mobname
  
  if Mobname ~= "" then
    RaidLeadTinyPadPageTitleEditBox:SetText("*" .. Mobname)
  else
    local Pagetitle = pages[current][1]
    --print("1st char: " .. string.sub(Pagetitle,1,1))
    --print("len: " .. string.len(Pagetitle))
    Pagetitle = string.sub(Pagetitle, 2, string.len(Pagetitle))
    RaidLeadTinyPadPageTitleEditBox:SetText(Pagetitle)
  end
	raidleadtinypad:SaveCurrentPage()
end

function raidleadtinypad:ToggleIndent()
	raidleadtinypad:SaveCurrentPage()
  if levels[current] == 1 then
    levels[current] = 2
  elseif levels[current] == 2 then
    levels[current] = 1
  end
  raidleadtinypad:UpdateBookmarks()
end

function raidleadtinypad:Broadcast()
  if UnitPlayerOrPetInRaid("player") == true then
    local rlpadChat = pages[current][2]
    local rlpadTimes = 0
    plpadChat,rlpadTimes = gsub(rlpadChat, "\n", " ")
    if UnitIsGroupLeader("player") == true or UnitIsGroupAssistant("player") == true then
      SendChatMessage(plpadChat, "RAID_WARNING", nil, nil)
    else
      SendChatMessage(plpadChat, "RAID", nil, nil)
    end
  else
    if UnitPlayerOrPetInParty("player") == true then
      SendChatMessage(plpadChat, "PARTY", nil, nil)
    end
  end
end

--function raidleadtinypad:NextPage()
--	raidleadtinypad:SaveCurrentPage()
--	current = min(#pages,current+1)
--	raidleadtinypad:ShowPage(current, true)
--end

--function raidleadtinypad:PreviousPage()
--	raidleadtinypad:SaveCurrentPage()
--	current = max(1,current-1)
--	raidleadtinypad:ShowPage(current, true)
--end

--function raidleadtinypad:FirstPage()
--	raidleadtinypad:SaveCurrentPage()
--	current = 1
--	raidleadtinypad:ShowPage(current, true)
--end

--function raidleadtinypad:LastPage()
--	raidleadtinypad:SaveCurrentPage()
--	current = #pages
--	raidleadtinypad:ShowPage(current, true)
--end

function raidleadtinypad:DeletePage(bypass)
	if IsShiftKeyDown() or bypass==true or RaidLeadTinyPadEditBox:GetText():len()==0 then
		tremove(pages,current)
		tremove(levels,current)
		tremove(mobs,current)
    local button = raidleadtinypad:FindBookmarkButton(current)
    button:Hide()
		if #pages==0 then
			tinsert(pages,{"Page 1", ""})
      tinsert(levels, 1)
      tinsert(mobs, "")
		end
		raidleadtinypad:ShowPage(min(#pages,current), true)
	else
		StaticPopupDialogs["TINYPADCONFIRM"] = StaticPopupDialogs["TINYPADCONFIRM"] or { text="Delete this page?", button1=YES, button2=NO, timeout=0, whileDead=1, OnAccept=function() raidleadtinypad:DeletePage(true) end}
		StaticPopup_Show("TINYPADCONFIRM")
	end
end

function raidleadtinypad:Undo()
	local position = RaidLeadTinyPadEditBox:GetCursorPosition()
	RaidLeadTinyPadEditBox:SetText(undoPage)
	RaidLeadTinyPadEditBox:SetCursorPosition(position)
end

--[[ moving pages ]]

-- swaps page number page1 with page number page2
function raidleadtinypad:SwapPages(page1,page2)
	if pages[page1] and pages[page2] then
		local save = pages[page1]
		pages[page1] = pages[page2]
		pages[page2] = save
	end
end

-- moves page number from to page number to
function raidleadtinypad:MovePage(from,to)
	if from<1 or from>#pages or to<1 or to>#pages then
		return -- don't allow a page to move beyond range of pages
	end
	local save = pages[from]
	tremove(pages,from)
	tinsert(pages,to,save)
end


function raidleadtinypad:ToggleBookmarks()
	RaidLeadTinyPadBookmarks:SetShown(not RaidLeadTinyPadBookmarks:IsShown())
end

function raidleadtinypad:Snooze()
	SnoozeStartTime = GetTime()
	raidleadtinypad:Toggle()
end

--[[ panel ]]
function raidleadtinypad:ToggleSettingsPanel()
	RaidLeadTinyPad.settingspanel:SetShown(not RaidLeadTinyPad.settingspanel:IsShown())
	if not RaidLeadTinyPad:IsVisible() then
		RaidLeadTinyPad:Show()
	end
	if RaidLeadTinyPad.settingspanel:IsShown() then
		RaidLeadTinyPad.settingspanel.searchBox:SetFocus()
	end
end

function raidleadtinypad:ToggleLock()
	settings.Lock = not settings.Lock
	--raidleadtinypad:UpdateESCable()
	raidleadtinypad:UpdateLock()
end

function raidleadtinypad:NextFont()
	local numFonts = #RaidLeadTinyPad.fonts
	settings.Font = (settings.Font+(IsShiftKeyDown() and (numFonts-2) or 0))%numFonts + 1
	raidleadtinypad:UpdateFont()
end

function raidleadtinypad:ToggleSize()
  settings.LargeScale = not settings.LargeScale
  raidleadtinypad:UpdateScale()
end

function raidleadtinypad:UpdateScale()
   if settings.LargeScale then
      RaidLeadTinyPad:SetScale(1.25)
      RaidLeadTinyPadBookmarks:SetScale(UIParent:GetEffectiveScale()/RaidLeadTinyPad:GetEffectiveScale())
   else
      RaidLeadTinyPad:SetScale(1)
      RaidLeadTinyPadBookmarks:SetScale(1)
   end
end

--[[ search ]]

local function literal(c) return "%"..c end
local function caseinsensitive(c) return format("[%s%s]",c:lower(),c:upper()) end

function raidleadtinypad:SearchOnTextChanged()
	if RaidLeadTinyPad.undo:IsEnabled() then
		raidleadtinypad:SaveCurrentPage()
		RaidLeadTinyPad.undo:Disable()
	end
	RaidLeadTinyPad.searchText = self:GetText():gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]",literal):gsub("%a",caseinsensitive)
	if RaidLeadTinyPad.searchText:len()>0 then
		raidleadtinypad:UpdateSearchCount()
		RaidLeadTinyPad.settingspanel.searchBox.clear:Show()
		RaidLeadTinyPad.settingspanel.find:Enable()
	else
		RaidLeadTinyPad.settingspanel.result:SetText("Search:")
		RaidLeadTinyPad.settingspanel.searchBox.clear:Hide()
		RaidLeadTinyPad.settingspanel.find:Disable()
	end
end

function raidleadtinypad:UpdateSearchCount()
	local search = RaidLeadTinyPad.searchText
	local count = 0
	for i=1,#pages do
		if raidleadtinypad:GetPageText(i):match(search) then
			count = count + 1
		end
	end
	RaidLeadTinyPad.settingspanel.result:SetText(format("%s\npages",count==0 and "no" or count))
end

function raidleadtinypad:SearchOnEnter()
	--print("SearchOnEnter")
	local search = RaidLeadTinyPad.searchText
	if search and search:len()>0 then
		if RaidLeadTinyPad.undo:IsEnabled() then
			raidleadtinypad:SaveCurrentPage()
			RaidLeadTinyPad.undo:Disable()
			raidleadtinypad:UpdateSearchCount()
		end
		local page = current
		local numPages = #pages
		local direction = IsShiftKeyDown() and -2 or 0
		for i=1,numPages do
			page = (page+direction)%numPages+1
			if raidleadtinypad:GetPageText(page):match(search) then
				raidleadtinypad:ShowPage(page, true)
				return
			end
		end
	end
end

--[[ bookmarks ]]

-- updates the bookmarks window to display all bookmarked pages
function raidleadtinypad:UpdateBookmarks()
	local bookmarks = RaidLeadTinyPadBookmarks
	bookmarks.buttons = bookmarks.buttons or {}
	bookmarks.prompt:Hide()
	local yoffset = 8
	local showBack = true
	for i=1,#pages do
    local button = raidleadtinypad:GetBookmarkButton(i)
    button:SetID(i)
    yoffset = yoffset - 18
    button.name:SetText(pages[i][1])
    button.back:SetShown(showBack)
    showBack = not showBack -- alternate whether back shows or not (lighter background)
    button.mark:SetShown(i==current) -- mark current page if it's this bookmark
    local buttonWidth = 235
    if i==current then
      buttonWidth = buttonWidth - 7 -- adjust width for mark
    end
    if levels[i] == 1 then
      button:SetPoint("TOPLEFT",5,yoffset)
    elseif levels[i] == 2 then
      buttonWidth = buttonWidth - 10 -- adjust width for indention
      button:SetPoint("TOPLEFT",15,yoffset)
    end
    --print(i .. ": " .. levels[i] .. ": " .. buttonWidth)
    button:SetWidth(buttonWidth)
    button.name:SetWidth(buttonWidth - 10)
    button:Show()
	end
	RaidLeadTinyPadBookmarks:SetHeight(-yoffset+24)
end

-- returns an available bookmark button from the frame, or a new blank one if needed.
function raidleadtinypad:GetBookmarkButton(i)
	for _,button in ipairs(RaidLeadTinyPadBookmarks.buttons) do
		if button:GetID() == i then
			return button
		end
	end
	local button = CreateFrame("Button",nil,RaidLeadTinyPadBookmarks,"RaidLeadTinyPadBookmarkTemplate")
	tinsert(RaidLeadTinyPadBookmarks.buttons,button)
	return button
end

function raidleadtinypad:FindBookmarkButton(i)
  --print("FindBookmarkButton" .. i)
	local bbuttons = RaidLeadTinyPadBookmarks.buttons
  --print("#: " .. #bbuttons)
	for _,button in ipairs(RaidLeadTinyPadBookmarks.buttons) do
		if button:GetID() == i then
      --print("Found it at " .. i)
			return button
		end
	end
end

function raidleadtinypad:BookmarkOnClick()
	if self:GetID()>0 then
		raidleadtinypad:ShowPage(self:GetID(), true)
	end
end

--[[ tooltips ]]

function RaidLeadTinyPad:ShowTooltip()
	if self.tooltipTitle then
		GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
		GameTooltip:AddLine(self.tooltipTitle)
		if self.tooltipBody then
			GameTooltip:AddLine(self.tooltipBody,.95,.95,.95,true)
		end
		GameTooltip:Show()
	end
end

function raidleadtinypad:ShowBookmarkTooltip()
	local page = self:GetID()
	GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
	--GameTooltip:AddLine(pages[page][1],1,.82,0,1)
	GameTooltip:AddLine(format("Page %d",page),.65,.65,.65)
	GameTooltip:AddLine(pages[page][2]:sub(1,128):gsub("\n"," "),.9,.9,.9,1)
	GameTooltip:Show()
end

--[[ slash handler ]]

-- /pad # will go to a page, /pad run # will run a page, /pad alone toggles window
function RaidLeadTinyPad.SlashHandler(msg)
	msg = (msg or ""):lower()
	raidleadtinypad:Toggle()
end

--[[ functions for outside use ]]

-- this will delete all pages that contain a regex (ie "^Glyphioneer Suggestions"
-- will delete all pages that begin (^) with "Glyphioneer Suggestions".  This
-- is used primarily for addons that generate a report and want to clean up
-- old copies of data.  Use carefully!
function raidleadtinypad:DeletePagesContaining(regex)
	if type(self)=="string" then -- RaidLeadTinyPad.Delete... was used instead of RaidLeadTinyPad:Delete...
		regex = self
	end
	if type(regex)=="string" then
		for i=#pages,1,-1 do
			if raidleadtinypad:GetPageText(i):match(regex) then
				tremove(pages,i)
			end
		end
		if #pages==0 then
			tinsert(pages,{"", ""})
		end
		current = min(current,#pages)
		raidleadtinypad:ShowPage(current, true)
	end
end

	local rltpForTesting = true
-- RaidLeadTinyPad:Insert("body") -- creates a new page with "text"
-- RaidLeadTinyPad:Insert("body","title") -- creates a new page bookmarked as "title" that contains "text"
-- RaidLeadTinyPad:Insert("body",<number>) -- creates a new page with "text" at page <number>
-- RaidLeadTinyPad:Insert("body",<number>,"title") -- creates a new page bookmarked as "title" that contains "text" at page <number>
function raidleadtinypad:OnUpdate(self, elapsed)
	if InCombat == true then
--		if rltpForTesting == true then
--			SendChatMessage("Testing in combat")
--			rltpForTesting = false
--		else
--			SendChatMessage("Testing not in combat")
--			rltpForTesting = false
--		end

		if RaidLeadTinyPad:IsVisible() then
			raidleadtinypad:Toggle()			
		end
	end
end

function raidleadtinypad:Insert(body,page,bookmark)
	if type(self)=="string" then -- RaidLeadTinyPad.Insert was used instead of RaidLeadTinyPad:Insert
		bookmark = page
		page = body
		body = self
	end
	if not type(body)=="string" then
		return -- a valid body not given, leave
	end
	if not page then -- ("body")
		tinsert(pages,body)
		current = #pages
	elseif type(page)=="string" then -- ("body","title")
		tinsert(pages,{page,body})
		current = #pages
	else -- page is a number
		page = max(1,min(#pages+1,page)) -- make sure it's in range
    tinsert(pages,page,{bookmark,body}) -- ("body",<number>,"title")
		current = page
	end
	raidleadtinypad:ShowPage(current, true)
end
