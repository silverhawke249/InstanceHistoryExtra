local _, env = ...

-- Create options frame
local optionsFrame = CreateFrame("Frame", nil, UIParent)
optionsFrame.name = "Instance History Extra"
optionsFrame.settingChanges = {}
function optionsFrame.default()
    local db = InstanceHistoryExtraSV
    db.config = env.deepcopy(env.configDefaults)
    optionsFrame.populateOptions()
    env.f.drawProgressBar()
end
env.optionsFrame = optionsFrame
InterfaceOptions_AddCategory(optionsFrame)

local scale = UIParent:GetEffectiveScale()
local swh, sh = floor(GetScreenWidth() * scale / 2), floor(GetScreenHeight() * scale)
local elements = {
    {type="check", text="Debug Mode", key="debugMode",
        desc="Prints debug messages to the default chat frame."},
    {type="check", text="Report Resets", key="reportResets",
        desc="Reports instance resets to group channels."},
    {type="check", text="Report Time Only When Locked", key="reportLockedOnly",
        desc="When disabled, will always report time until oldest instance expires, unless under hourly lock. Otherwise, only report time when locked out." },
    {type="check", text="Colorize Display Segment", key="colorProgress",
        desc="Applies color to individual segments of the display."},
    {type="check", text="Force 24-Hour Display", key="force24H",
        desc="Forces display to show 24 hours instead of dynamically changing."},
    {type="padding"},
    {type="slider", text="Display Update Interval", key="updateInterval", min=0.5, max=10, step=0.5,
        desc="Number of seconds to wait between each display update."},
    {type="slider", text="Display Threshold", key="displayMin", min=1, max=30, step=1,
        desc="Minimum number of instances before display appears."},
    {type="slider", text="Width", key="width", min=0, max=500, step=1},
    {type="slider", text="Height", key="height", min=0, max=100, step=1},
    {type="slider", text="Horizontal Position", key="xOffset", min=-swh, max=swh, step=1},
    {type="slider", text="Vertical Position", key="yOffset", min=0, max=sh, step=1},
    {type="slider", text="Font Size", key="fontSize", min=8, max=32, step=1},
}
local xSpace = 290
local xOfs = 20

-- Header
local fs = optionsFrame:CreateFontString(nil, "ARTWORK")
fs:SetFontObject(GameFontNormalLarge)
fs:SetText("Instance History Extra")
fs:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -20)

local line = optionsFrame:CreateLine()
line:SetColorTexture(1, 1, 1, 0.3)
line:SetStartPoint("TOPLEFT", fs, 0, -3 - fs:GetStringHeight())
line:SetEndPoint("TOPRIGHT", fs, 5, -3 - fs:GetStringHeight())
line:SetThickness(1.5)

-- Populate options
optionsFrame.formElements = {}
local ypos = -20
for i, d in ipairs(elements) do
    local e
    local x = (i - 1) % 2

    if d.type == "check" then
        if x == 0 then
            ypos = ypos - 30
        end
        e = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
        e.text:SetText(d.text)
        e.text:SetFontObject(GameFontHighlight)
        e:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", xOfs + x * xSpace, ypos)
        e:SetScript("OnClick", function(self)
            local db = InstanceHistoryExtraSV
            db.config[self.configKey] = self:GetChecked()
            env.f.drawProgressBar()
        end)
        if d.desc then
            e:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:AddLine(d.text)
                GameTooltip:AddLine(d.desc, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            e:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    elseif d.type == "slider" then
        if x == 0 then
            ypos = ypos - 60
        end
        -- Create slider
        e = CreateFrame("Slider", nil, optionsFrame, "OptionsSliderTemplate")
        e:SetOrientation("HORIZONTAL")
        e:SetWidth(xSpace - 50)
        e:SetMinMaxValues(d.min, d.max)
        e:SetValueStep(d.step)
        e:SetObeyStepOnDrag(true)
        e:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", xOfs + x * xSpace + 25, ypos)
        e:SetScript("OnValueChanged", function(self, val)
            self.editBox:SetNumber(val)
            -- save config, refresh progress bar
            local db = InstanceHistoryExtraSV
            db.config[self.configKey] = val
            env.f.drawProgressBar()
        end)
        -- Create attached editbox
        e.editBox = CreateFrame("EditBox", nil, e)
        e.editBox:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
            edgeSize = 16,
            insets = {left = 8, right = 6, top = 8, bottom = 8},
        })
        e.editBox:SetBackdropColor(0, 0, 0, 1)
        e.editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        e.editBox:SetSize(60, 30)
        e.editBox:SetMultiLine(false)
        e.editBox:SetAutoFocus(false)
        e.editBox:SetJustifyH("CENTER")
        e.editBox:SetJustifyV("CENTER")
        e.editBox:SetFontObject(GameFontWhiteSmall)
        e.editBox:SetScript("OnArrowPressed", function(self, key)
            local vmin, vmax = self:GetParent():GetMinMaxValues()
            local step = self:GetParent():GetValueStep()
            local val = self:GetNumber()
            -- increase/decrease value depending on step value
            if key == "UP" then
                val = val + step
            elseif key == "DOWN" then
                val = val - step
            end
            -- clamping
            val = max(vmin, min(vmax, val))
            -- set numbers (thanks floats)
            self:GetParent():SetValue(val)
            self:SetNumber(self:GetParent():GetValue(val))
            -- save config, refresh progress bar
            local db = InstanceHistoryExtraSV
            db.config[self:GetParent().configKey] = self:GetNumber()
            env.f.drawProgressBar()
        end)
        e.editBox:SetScript("OnEnterPressed", function(self)
            local vmin, vmax = self:GetParent():GetMinMaxValues()
            local val = self:GetNumber()
            -- clamping
            val = max(vmin, min(vmax, val))
            self:SetNumber(val)
            self:GetParent():SetValue(val)
            -- to accommodate step values
            self:SetNumber(self:GetParent():GetValue(val))
            self:ClearFocus()
            -- save config, refresh progress bar
            local db = InstanceHistoryExtraSV
            db.config[self:GetParent().configKey] = self:GetNumber()
            env.f.drawProgressBar()
        end)
        e.editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(self:GetParent():GetValue(val))
            self:ClearFocus()
        end)
        if d.desc then
            e:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:AddLine(d.text)
                GameTooltip:AddLine(d.desc, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            e:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        -- Modify labels
        e.Low:SetText(d.min)
        e.High:SetText(d.max)
        e.Text:SetText(d.text)
        e.Text:SetFontObject(GameFontNormal)
        e.editBox:SetPoint("TOP", e.Text, "BOTTOM", 0, -10)
    end

    if e then
        e.configKey = d.key
        optionsFrame.formElements[d.key] = e
    end
end

-- Author info
local text = optionsFrame:CreateFontString(nil, "ARTWORK")
text:SetFontObject(GameFontDisableSmall)
text:SetText(env.c.authorInfo)
text:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -10, 10)

function optionsFrame.populateOptions()
    local db = InstanceHistoryExtraSV
    for k, v in pairs(db.config) do
        local e = optionsFrame.formElements[k]
        if e then
            local type = e:GetObjectType()
            if type == "CheckButton" then
                e:SetChecked(v)
            elseif type == "Slider" then
                e:SetValue(v)
                e.editBox:SetNumber(v)
                e.editBox:SetCursorPosition(0)
            end
        end
    end
end
