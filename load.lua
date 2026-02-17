local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local Library = {}

local BaseTheme = {
	Background = Color3.fromRGB(5, 5, 5),
	Surface = Color3.fromRGB(8, 8, 8),
	Topbar = Color3.fromRGB(5, 5, 5),
	Sidebar = Color3.fromRGB(7, 7, 7),
	Inset = Color3.fromRGB(15, 15, 15),
	ItemBackground = Color3.fromRGB(15, 15, 15),
	Border = Color3.fromRGB(40, 40, 40),
	HoverBorder = Color3.fromRGB(58, 58, 58),
	ActiveBorder = Color3.fromRGB(160, 230, 240),
	Accent = Color3.fromRGB(160, 230, 240),
	TextMuted = Color3.fromRGB(200, 200, 200),
	SecondaryText = Color3.fromRGB(120, 120, 120),
	PlaceholderText = Color3.fromRGB(120, 120, 120),
	ButtonText = Color3.fromRGB(200, 200, 200),
	ButtonBorder = Color3.fromRGB(40, 40, 40),
	Icon = Color3.fromRGB(120, 120, 120),
}

local BaseFonts = {
	Header = Enum.Font.GothamBold,
	Nav = Enum.Font.Gotham,
	Item = Enum.Font.RobotoMono,
	Code = Enum.Font.RobotoMono,
}

local BaseConfig = {
	Name = "SingularityWindow",
	Title = "SINGULARITY // CORE",
	Subtitle = "SYSTEM UTILITY",
	Size = UDim2.fromOffset(820, 520),
	Position = UDim2.fromScale(0.5, 0.5),
	TopbarHeight = 40,
	TabRailWidth = 180,
	ItemHeight = 30,
	MenuBind = Enum.KeyCode.RightControl,
	Visible = true,
}

-- Gradients are optional, but disabled by default for the Juju Live minimalist look.
local BaseGradients = {
	Enabled = false,
	Main = {Enabled = false},
	TopBar = {Enabled = false},
	Topbar = {Enabled = false},
	Body = {Enabled = false},
	TabRail = {Enabled = false},
	Sidebar = {Enabled = false},
	Page = {Enabled = false},
	Section = {Enabled = false},
	Groupbox = {Enabled = false},
	GroupboxHeader = {Enabled = false},
	AccentButton = {Enabled = false},
	Input = {Enabled = false},
	ToggleRow = {Enabled = false},
	TabButton = {Enabled = false},
	Item = {Enabled = false},
}

local function cloneValue(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, entry in pairs(value) do
		copy[key] = cloneValue(entry)
	end
	return copy
end

local function isArray(tbl)
	local count = 0
	for key in pairs(tbl) do
		if type(key) ~= "number" then
			return false
		end
		count = count + 1
	end
	return count > 0
end

local function mergeTables(base, overrides)
	local result = cloneValue(base)
	if type(overrides) ~= "table" then
		return result
	end

	for key, value in pairs(overrides) do
		if type(value) == "table" and type(result[key]) == "table" and not isArray(value) and not isArray(result[key]) then
			result[key] = mergeTables(result[key], value)
		else
			result[key] = cloneValue(value)
		end
	end

	return result
end

local function normalizeTheme(theme)
	theme.Sidebar = theme.Sidebar or theme.Surface
	theme.ItemBackground = theme.ItemBackground or theme.Inset
	theme.ActiveBorder = theme.ActiveBorder or theme.Accent
	theme.ButtonText = theme.ButtonText or theme.TextMuted
	theme.ButtonBorder = theme.ButtonBorder or theme.Border
	theme.PlaceholderText = theme.PlaceholderText or theme.SecondaryText
	theme.Icon = theme.Icon or theme.SecondaryText
	return theme
end

local function sanitizeName(text, fallback)
	local clean = tostring(text or ""):gsub("[^%w_]+", "")
	if clean == "" then
		return fallback or "Item"
	end
	return clean
end

local function makeStroke(target, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	return stroke
end

local function tween(instance, info, goals)
	local animation = TweenService:Create(instance, info, goals)
	animation:Play()
	return animation
end

local function getGuiParent(customParent)
	if customParent then
		return customParent
	end

	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end

	return game:GetService("CoreGui")
end

local function safeCallback(callback, ...)
	if not callback then
		return
	end

	task.spawn(function(...)
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[SingularityUI] callback error:", err)
		end
	end, ...)
end

local function toColorSequence(value, fallbackA, fallbackB)
	if typeof(value) == "ColorSequence" then
		return value
	end

	if typeof(value) == "table" then
		if typeof(value.From) == "Color3" and typeof(value.To) == "Color3" then
			return ColorSequence.new(value.From, value.To)
		end

		if #value >= 2 and typeof(value[1]) == "Color3" then
			local keypoints = {}
			local divisor = #value - 1
			for index, color in ipairs(value) do
				keypoints[index] = ColorSequenceKeypoint.new((index - 1) / divisor, color)
			end
			return ColorSequence.new(keypoints)
		end
	end

	return ColorSequence.new(fallbackA, fallbackB)
end

local function toNumberSequence(value, fallback)
	if typeof(value) == "NumberSequence" then
		return value
	end

	if type(value) == "number" then
		return NumberSequence.new(value)
	end

	return NumberSequence.new(fallback or 0)
end

local function makeGradient(target, gradientConfig, fallbackA, fallbackB)
	if type(gradientConfig) ~= "table" or gradientConfig.Enabled == false then
		return nil
	end

	local gradient = Instance.new("UIGradient")
	gradient.Color = toColorSequence(gradientConfig.Color, fallbackA, fallbackB)
	gradient.Rotation = gradientConfig.Rotation or 90
	if typeof(gradientConfig.Offset) == "Vector2" then
		gradient.Offset = gradientConfig.Offset
	end
	if gradientConfig.Transparency ~= nil then
		gradient.Transparency = toNumberSequence(gradientConfig.Transparency, 0)
	end
	gradient.Parent = target
	return gradient
end

local function resolveGradients(gradientOptions)
	local gradients = cloneValue(BaseGradients)
	if typeof(gradientOptions) == "boolean" then
		gradients.Enabled = gradientOptions
	elseif type(gradientOptions) == "table" then
		gradients = mergeTables(gradients, gradientOptions)
	end

	if gradients.Enabled == false then
		for key, value in pairs(gradients) do
			if key ~= "Enabled" and type(value) == "table" then
				value.Enabled = false
			end
		end
	end

	return gradients
end

local function splitCallbackAndOptions(callbackOrOptions, options)
	if type(callbackOrOptions) == "table" and options == nil then
		return nil, callbackOrOptions
	end
	return callbackOrOptions, options or {}
end

local function measureTextWidth(text, font, textSize)
	local bounds = TextService:GetTextSize(tostring(text), textSize, font, Vector2.new(1000, 1000))
	return bounds.X
end

local function attachBorderCutoutTitle(frame, text, font, textSize, theme, leftPadding)
	frame.ClipsDescendants = false

	local label = Instance.new("TextLabel")
	label.Name = "BorderTitle"
	label.Parent = frame
	label.BackgroundColor3 = theme.Background
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, leftPadding or 10, 0, -10)
	label.Size = UDim2.fromOffset(measureTextWidth(text, font, textSize) + 12, 18)
	label.Font = font
	label.Text = tostring(text)
	label.TextColor3 = theme.TextMuted
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = (frame.ZIndex or 1) + 2
	return label
end

local function createIconSlot(parent, theme, options)
	local iconOptions = options or {}

	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.Parent = parent
	iconSlot.Position = UDim2.new(0, 8, 0.5, -8)
	iconSlot.Size = UDim2.fromOffset(16, 16)
	iconSlot.BackgroundTransparency = 1
	iconSlot.BorderSizePixel = 0

	local slotStroke = makeStroke(iconSlot, theme.Border)
	slotStroke.Transparency = 0.25

	local iconImage = iconOptions.Icon
	if type(iconImage) == "string" and iconImage ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.Parent = iconSlot
		image.BackgroundTransparency = 1
		image.Position = UDim2.new(0, 1, 0, 1)
		image.Size = UDim2.new(1, -2, 1, -2)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = iconImage
		image.ImageColor3 = iconOptions.IconColor or theme.Icon
	end

	return 30, iconSlot
end

Library.Defaults = {
	Config = cloneValue(BaseConfig),
	Theme = cloneValue(BaseTheme),
	Fonts = cloneValue(BaseFonts),
	Gradients = cloneValue(BaseGradients),
}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Groupbox = {}
Groupbox.__index = Groupbox

function Window:_trackConnection(connection)
	table.insert(self._connections, connection)
	return connection
end

function Window:_trackHover(target, stroke, defaultColor, hoverColor)
	self:_trackConnection(target.MouseEnter:Connect(function()
		tween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = hoverColor,
		})
	end))

	self:_trackConnection(target.MouseLeave:Connect(function()
		tween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = defaultColor,
		})
	end))
end

function Window:_makeDraggable(handle, target)
	local dragging = false
	local dragInput = nil
	local dragStart = Vector2.zero
	local startPosition = target.Position

	self:_trackConnection(handle.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		dragStart = input.Position
		startPosition = target.Position

		local stopConn
		stopConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				stopConn:Disconnect()
			end
		end)
		self:_trackConnection(stopConn)
	end))

	self:_trackConnection(handle.InputChanged:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))

	self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
		if not dragging or input ~= dragInput then
			return
		end

		local delta = input.Position - dragStart
		target.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))
end

function Window:_bindMenuToggle()
	self:_trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not self._menuBind then
			return
		end
		if gameProcessed then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == self._menuBind then
			self:Toggle()
		end
	end))
end

function Window:SetMenuBind(keyCode)
	if keyCode == nil or keyCode == false then
		self._menuBind = nil
		return
	end
	if typeof(keyCode) ~= "EnumItem" or keyCode.EnumType ~= Enum.KeyCode then
		return
	end
	self._menuBind = keyCode
end

function Window:GetMenuBind()
	return self._menuBind
end

function Window:SetVisible(isVisible)
	if self._destroyed then
		return
	end

	local nextState = isVisible == true
	if self._visible == nextState then
		return
	end
	self._visible = nextState

	if nextState then
		self._screenGui.Enabled = true
		tween(self._main, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = self._targetSize,
		})
		return
	end

	tween(self._main, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(self._targetSize.X.Scale, self._targetSize.X.Offset, 0, 0),
	})
	task.wait(0.11)
	if not self._destroyed and self._screenGui then
		self._screenGui.Enabled = false
	end
end

function Window:Toggle()
	self:SetVisible(not self._visible)
end

function Window:IsVisible()
	return self._visible
end

function Window:SetTitle(title, subtitle)
	if title ~= nil then
		self._titleLabel.Text = tostring(title)
	end
	if subtitle ~= nil then
		self._subtitleLabel.Text = tostring(subtitle)
	end
end

function Window:SelectTab(tabToSelect)
	if self._destroyed then
		return
	end

	local selected = tabToSelect
	if typeof(tabToSelect) == "string" then
		for _, tab in ipairs(self._tabs) do
			if tab.Name == tabToSelect then
				selected = tab
				break
			end
		end
	end

	if typeof(selected) ~= "table" or selected._window ~= self then
		return
	end

	if self._activeTab == selected then
		return
	end

	local theme = self._theme
	self._activeTab = selected

	for _, tab in ipairs(self._tabs) do
		local isActive = tab == selected
		tab._page.Visible = isActive

		tween(tab._label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = if isActive then theme.Accent else theme.SecondaryText,
		})

		tween(tab._activeBar, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = if isActive then 0 else 1,
		})
	end

	task.wait()
end

function Window:CreateTab(name, options)
	if self._destroyed then
		error("Cannot create tab on a destroyed window.", 2)
	end

	options = options or {}

	local theme = self._theme
	local fonts = self._fonts
	local gradients = self._gradients

	local tab = setmetatable({
		Name = tostring(name),
		_window = self,
	}, Tab)

	local cleanName = sanitizeName(name, "Tab")

	local tabButton = Instance.new("TextButton")
	tabButton.Name = "Tab_" .. cleanName
	tabButton.Parent = self._tabButtonList
	tabButton.Size = UDim2.new(1, 0, 0, 30)
	tabButton.BackgroundTransparency = 1
	tabButton.BorderSizePixel = 0
	tabButton.AutoButtonColor = false
	tabButton.Text = ""

	local activeBar = Instance.new("Frame")
	activeBar.Name = "ActiveBar"
	activeBar.Parent = tabButton
	activeBar.BackgroundColor3 = theme.Accent
	activeBar.BackgroundTransparency = 1
	activeBar.BorderSizePixel = 0
	activeBar.Position = UDim2.new(0, 2, 0.5, -7)
	activeBar.Size = UDim2.new(0, 2, 0, 14)

	local tabLabel = Instance.new("TextLabel")
	tabLabel.Name = "Label"
	tabLabel.Parent = tabButton
	tabLabel.BackgroundTransparency = 1
	tabLabel.Position = UDim2.new(0, 12, 0, 0)
	tabLabel.Size = UDim2.new(1, -14, 1, 0)
	tabLabel.Font = fonts.Nav
	tabLabel.Text = tostring(name)
	tabLabel.TextColor3 = theme.SecondaryText
	tabLabel.TextSize = 14
	tabLabel.TextXAlignment = Enum.TextXAlignment.Left

	makeGradient(tabButton, gradients.TabButton or gradients.Item, theme.ItemBackground, theme.Background)

	self:_trackConnection(tabButton.MouseEnter:Connect(function()
		if self._activeTab ~= tab then
			tween(tabLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = theme.TextMuted,
			})
		end
	end))

	self:_trackConnection(tabButton.MouseLeave:Connect(function()
		if self._activeTab ~= tab then
			tween(tabLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = theme.SecondaryText,
			})
		end
	end))

	local tabPage = Instance.new("ScrollingFrame")
	tabPage.Name = "Page_" .. cleanName
	tabPage.Parent = self._pageContainer
	tabPage.BackgroundColor3 = theme.Background
	tabPage.BorderSizePixel = 0
	tabPage.Size = UDim2.new(1, 0, 1, 0)
	tabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabPage.ScrollBarThickness = 4
	tabPage.ScrollBarImageColor3 = theme.Border
	tabPage.Visible = false

	makeGradient(tabPage, gradients.Page, theme.Surface, theme.Background)

	local pagePadding = Instance.new("UIPadding")
	pagePadding.Parent = tabPage
	pagePadding.PaddingTop = UDim.new(0, 14)
	pagePadding.PaddingBottom = UDim.new(0, 14)
	pagePadding.PaddingLeft = UDim.new(0, 14)
	pagePadding.PaddingRight = UDim.new(0, 14)

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Parent = tabPage
	pageLayout.FillDirection = Enum.FillDirection.Vertical
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Padding = UDim.new(0, 12)

	tab._button = tabButton
	tab._label = tabLabel
	tab._activeBar = activeBar
	tab._page = tabPage
	tab._layout = pageLayout

	self:_trackConnection(tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end))

	table.insert(self._tabs, tab)
	if not self._activeTab then
		self:SelectTab(tab)
	end

	return tab
end

function Window:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	tween(self._main, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(self._main.Size.X.Scale, self._main.Size.X.Offset, 0, 0),
	})
	task.wait(0.15)

	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)

	if self._screenGui then
		self._screenGui:Destroy()
	end
end

local function getComponentContext(self)
	local window = self._window
	local parent = self._content or self._page
	local theme = window._theme
	local fonts = window._fonts
	local gradients = window._gradients
	local config = window._config
	return window, parent, theme, fonts, gradients, config
end

function Tab:CreateGroupbox(title, options)
	options = options or {}

	local window, parent, theme, fonts, gradients = getComponentContext(self)
	local cleanName = sanitizeName(title, "Groupbox")
	local sidePadding = options.Padding or 10
	local contentTopPadding = options.ContentTopPadding or 10
	local contentBottomPadding = options.ContentBottomPadding or 10
	local topInset = options.TopInset or 12

	local groupFrame = Instance.new("Frame")
	groupFrame.Name = "Groupbox_" .. cleanName
	groupFrame.Parent = parent
	groupFrame.Size = UDim2.new(1, 0, 0, 0)
	groupFrame.AutomaticSize = Enum.AutomaticSize.Y
	groupFrame.BackgroundTransparency = 1
	groupFrame.BorderSizePixel = 0
	groupFrame.Active = true

	local groupStroke = makeStroke(groupFrame, theme.Border)
	makeGradient(groupFrame, gradients.Groupbox, theme.Surface, theme.Background)
	window:_trackHover(groupFrame, groupStroke, theme.Border, theme.HoverBorder)

	attachBorderCutoutTitle(groupFrame, title, fonts.Header, 13, theme, sidePadding)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Parent = groupFrame
	content.Position = UDim2.new(0, sidePadding, 0, topInset)
	content.Size = UDim2.new(1, -(sidePadding * 2), 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1

	local contentPadding = Instance.new("UIPadding")
	contentPadding.Parent = content
	contentPadding.PaddingTop = UDim.new(0, contentTopPadding)
	contentPadding.PaddingBottom = UDim.new(0, contentBottomPadding)

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Parent = content
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)

	local groupbox = setmetatable({
		Name = tostring(title),
		_window = window,
		_container = groupFrame,
		_content = content,
		_layout = contentLayout,
	}, Groupbox)

	return groupbox
end

function Tab:CreateSection(title)
	local _, parent, theme, fonts, gradients = getComponentContext(self)

	local section = Instance.new("Frame")
	section.Name = "Section_" .. sanitizeName(title, "Section")
	section.Parent = parent
	section.Size = UDim2.new(1, 0, 0, 22)
	section.BackgroundTransparency = 1
	section.BorderSizePixel = 0
	section.Active = true

	makeStroke(section, theme.Border)
	makeGradient(section, gradients.Section or gradients.Groupbox, theme.Surface, theme.Background)
	attachBorderCutoutTitle(section, title, fonts.Header, 13, theme, 10)

	return section
end

function Tab:CreateButton(text, callback, options)
	callback, options = splitCallbackAndOptions(callback, options)

	local window, parent, theme, fonts, gradients, config = getComponentContext(self)
	local itemHeight = options.Height or config.ItemHeight

	local button = Instance.new("TextButton")
	button.Name = "Button_" .. sanitizeName(text, "Button")
	button.Parent = parent
	button.Size = UDim2.new(1, 0, 0, itemHeight)
	button.BackgroundColor3 = theme.ItemBackground
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""

	local buttonStroke = makeStroke(button, theme.ButtonBorder)
	makeGradient(button, gradients.AccentButton or gradients.Item, theme.ItemBackground, theme.Background)
	window:_trackHover(button, buttonStroke, theme.ButtonBorder, theme.HoverBorder)

	local textLeft = createIconSlot(button, theme, options)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = button
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, textLeft, 0, 0)
	label.Size = UDim2.new(1, -(textLeft + 8), 1, 0)
	label.Font = fonts.Item
	label.Text = tostring(text)
	label.TextColor3 = theme.ButtonText
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left

	window:_trackConnection(button.MouseButton1Click:Connect(function()
		tween(buttonStroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.ActiveBorder,
		})
		task.wait(0.05)
		tween(buttonStroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.ButtonBorder,
		})
		safeCallback(callback)
	end))

	return button
end

function Tab:CreateInput(placeholder, callback, options)
	callback, options = splitCallbackAndOptions(callback, options)

	local window, parent, theme, fonts, gradients, config = getComponentContext(self)
	local itemHeight = options.Height or config.ItemHeight

	local holder = Instance.new("Frame")
	holder.Name = "Input_" .. sanitizeName(placeholder, "Input")
	holder.Parent = parent
	holder.Size = UDim2.new(1, 0, 0, itemHeight)
	holder.BackgroundColor3 = theme.Inset
	holder.BorderSizePixel = 0
	holder.Active = true

	local holderStroke = makeStroke(holder, theme.Border)
	makeGradient(holder, gradients.Input or gradients.Item, theme.Inset, theme.Background)
	window:_trackHover(holder, holderStroke, theme.Border, theme.HoverBorder)

	local textLeft = createIconSlot(holder, theme, options)

	local input = Instance.new("TextBox")
	input.Name = "TextBox"
	input.Parent = holder
	input.BackgroundTransparency = 1
	input.Position = UDim2.new(0, textLeft, 0, 0)
	input.Size = UDim2.new(1, -(textLeft + 8), 1, 0)
	input.Font = fonts.Item
	input.Text = options.DefaultText or ""
	input.PlaceholderText = tostring(placeholder)
	input.TextColor3 = theme.TextMuted
	input.PlaceholderColor3 = theme.PlaceholderText
	input.TextSize = 13
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left

	window:_trackConnection(input.Focused:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.ActiveBorder,
		})
	end))

	window:_trackConnection(input.FocusLost:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.Border,
		})
		safeCallback(callback, input.Text)
	end))

	return input
end

function Tab:CreateToggle(text, callback, options)
	callback, options = splitCallbackAndOptions(callback, options)

	local window, parent, theme, fonts, gradients, config = getComponentContext(self)
	local itemHeight = options.Height or config.ItemHeight

	local row = Instance.new("TextButton")
	row.Name = "Toggle_" .. sanitizeName(text, "Toggle")
	row.Parent = parent
	row.Size = UDim2.new(1, 0, 0, itemHeight)
	row.BackgroundColor3 = theme.ItemBackground
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Text = ""

	local rowStroke = makeStroke(row, theme.Border)
	makeGradient(row, gradients.ToggleRow or gradients.Item, theme.ItemBackground, theme.Background)
	window:_trackHover(row, rowStroke, theme.Border, theme.HoverBorder)

	local textLeft = createIconSlot(row, theme, options)

	local checkbox = Instance.new("Frame")
	checkbox.Name = "Checkbox"
	checkbox.Parent = row
	checkbox.Position = UDim2.new(0, textLeft, 0.5, -6)
	checkbox.Size = UDim2.new(0, 12, 0, 12)
	checkbox.BackgroundColor3 = theme.Background
	checkbox.BorderSizePixel = 0

	local checkboxStroke = makeStroke(checkbox, theme.Border)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Parent = checkbox
	fill.Position = UDim2.new(0, 2, 0, 2)
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.BackgroundColor3 = theme.Accent
	fill.BorderSizePixel = 0
	fill.BackgroundTransparency = 1

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = row
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, textLeft + 20, 0, 0)
	label.Size = UDim2.new(1, -(textLeft + 26), 1, 0)
	label.Text = tostring(text)
	label.Font = fonts.Item
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = theme.TextMuted

	local state = false
	local function setState(nextState, skipCallback)
		state = nextState == true
		tween(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = if state then 0 else 1,
		})
		tween(checkboxStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if state then theme.ActiveBorder else theme.Border,
		})
		if not skipCallback then
			safeCallback(callback, state)
		end
	end

	window:_trackConnection(row.MouseButton1Click:Connect(function()
		setState(not state, false)
	end))

	if options.Default ~= nil then
		setState(options.Default, true)
	end

	return {
		Set = function(_, nextState)
			setState(nextState, false)
		end,
		Get = function()
			return state
		end,
	}
end

function Groupbox:Destroy()
	if self._container then
		self._container:Destroy()
	end
end

Groupbox.CreateGroupbox = Tab.CreateGroupbox
Groupbox.CreateSection = Tab.CreateSection
Groupbox.CreateButton = Tab.CreateButton
Groupbox.CreateInput = Tab.CreateInput
Groupbox.CreateToggle = Tab.CreateToggle

function Library.CreateWindow(options)
	options = options or {}

	local config = mergeTables(BaseConfig, options)
	local theme = normalizeTheme(mergeTables(BaseTheme, options.Theme))
	local fonts = mergeTables(BaseFonts, options.Fonts)
	local gradients = resolveGradients(options.Gradients)

	local targetSize = config.Size
	local topbarHeight = config.TopbarHeight
	local tabRailWidth = config.TabRailWidth

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = config.Name
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = getGuiParent(config.Parent)
	screenGui.Enabled = config.Visible == true

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Parent = screenGui
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = config.Position
	main.Size = UDim2.new(targetSize.X.Scale, targetSize.X.Offset, 0, if config.Visible then targetSize.Y.Offset else 0)
	main.BackgroundColor3 = theme.Background
	main.BorderSizePixel = 0

	makeStroke(main, theme.Border)
	makeGradient(main, gradients.Main, theme.Surface, theme.Background)

	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Parent = main
	topbar.Size = UDim2.new(1, 0, 0, topbarHeight)
	topbar.BackgroundColor3 = theme.Topbar
	topbar.BorderSizePixel = 0
	topbar.Active = true

	makeStroke(topbar, theme.Border)
	makeGradient(topbar, gradients.TopBar or gradients.Topbar, theme.Topbar, theme.Surface)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Parent = topbar
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 12, 0, 4)
	titleLabel.Size = UDim2.new(1, -24, 0, 18)
	titleLabel.Text = config.Title
	titleLabel.Font = fonts.Header
	titleLabel.TextSize = 15
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = theme.Accent

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Parent = topbar
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 12, 0, 21)
	subtitleLabel.Size = UDim2.new(1, -24, 0, 15)
	subtitleLabel.Text = config.Subtitle
	subtitleLabel.Font = fonts.Item
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextColor3 = theme.SecondaryText

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Parent = main
	body.Position = UDim2.new(0, 0, 0, topbarHeight)
	body.Size = UDim2.new(1, 0, 1, -topbarHeight)
	body.BackgroundColor3 = theme.Background
	body.BorderSizePixel = 0

	makeGradient(body, gradients.Body, theme.Background, theme.Inset)

	local tabRail = Instance.new("Frame")
	tabRail.Name = "Sidebar"
	tabRail.Parent = body
	tabRail.Size = UDim2.new(0, tabRailWidth, 1, 0)
	tabRail.BackgroundColor3 = theme.Sidebar
	tabRail.BorderSizePixel = 0

	makeStroke(tabRail, theme.Border)
	makeGradient(tabRail, gradients.TabRail or gradients.Sidebar, theme.Sidebar, theme.Background)

	local railPadding = Instance.new("UIPadding")
	railPadding.Parent = tabRail
	railPadding.PaddingTop = UDim.new(0, 10)
	railPadding.PaddingBottom = UDim.new(0, 10)
	railPadding.PaddingLeft = UDim.new(0, 8)
	railPadding.PaddingRight = UDim.new(0, 8)

	local tabButtonList = Instance.new("Frame")
	tabButtonList.Name = "TabButtons"
	tabButtonList.Parent = tabRail
	tabButtonList.BackgroundTransparency = 1
	tabButtonList.Size = UDim2.new(1, 0, 1, 0)

	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Parent = tabButtonList
	tabListLayout.FillDirection = Enum.FillDirection.Vertical
	tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabListLayout.Padding = UDim.new(0, 4)

	local pageContainer = Instance.new("Frame")
	pageContainer.Name = "PageContainer"
	pageContainer.Parent = body
	pageContainer.Position = UDim2.new(0, tabRailWidth, 0, 0)
	pageContainer.Size = UDim2.new(1, -tabRailWidth, 1, 0)
	pageContainer.BackgroundColor3 = theme.Background
	pageContainer.BorderSizePixel = 0

	makeStroke(pageContainer, theme.Border)
	makeGradient(pageContainer, gradients.Page, theme.Surface, theme.Background)

	local window = setmetatable({
		_screenGui = screenGui,
		_main = main,
		_targetSize = targetSize,
		_titleLabel = titleLabel,
		_subtitleLabel = subtitleLabel,
		_tabButtonList = tabButtonList,
		_pageContainer = pageContainer,
		_tabs = {},
		_activeTab = nil,
		_connections = {},
		_destroyed = false,
		_visible = config.Visible == true,
		_menuBind = config.MenuBind,
		_theme = theme,
		_fonts = fonts,
		_gradients = gradients,
		_config = config,
	}, Window)

	window:_makeDraggable(topbar, main)
	window:_bindMenuToggle()

	if config.Visible == true then
		main.Size = UDim2.new(targetSize.X.Scale, targetSize.X.Offset, 0, 0)
		tween(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = targetSize,
		})
		task.wait(0.03)
	end

	return window
end

return Library
