local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {}

local BaseTheme = {
	Background = Color3.fromRGB(10, 10, 10),
	Surface = Color3.fromRGB(14, 14, 14),
	Topbar = Color3.fromRGB(18, 18, 18),
	Inset = Color3.fromRGB(7, 7, 7),
	Border = Color3.fromRGB(45, 45, 45),
	HoverBorder = Color3.fromRGB(68, 68, 68),
	ActiveBorder = Color3.fromRGB(95, 95, 95),
	Accent = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(165, 165, 165),
	ButtonText = Color3.fromRGB(0, 0, 0),
	ButtonBorder = Color3.fromRGB(20, 20, 20),
}

local BaseFonts = {
	Header = Enum.Font.GothamBold,
	Code = Enum.Font.Code,
}

local BaseConfig = {
	Name = "SingularityWindow",
	Title = "SINGULARITY UI",
	Subtitle = "SYSTEM CONTROL",
	Size = UDim2.fromOffset(780, 500),
	Position = UDim2.fromScale(0.5, 0.5),
	TopbarHeight = 44,
	TabRailWidth = 170,
	MenuBind = Enum.KeyCode.RightControl,
	Visible = true,
}

local BaseGradients = {
	Enabled = true,
	Main = {
		Enabled = true,
		Color = {Color3.fromRGB(13, 13, 13), Color3.fromRGB(9, 9, 9)},
		Rotation = 90,
	},
	TopBar = {
		Enabled = true,
		Color = {Color3.fromRGB(28, 28, 28), Color3.fromRGB(18, 18, 18)},
		Rotation = 0,
	},
	Body = {
		Enabled = true,
		Color = {Color3.fromRGB(12, 12, 12), Color3.fromRGB(9, 9, 9)},
		Rotation = 90,
	},
	TabRail = {
		Enabled = true,
		Color = {Color3.fromRGB(18, 18, 18), Color3.fromRGB(12, 12, 12)},
		Rotation = 90,
	},
	Page = {
		Enabled = true,
		Color = {Color3.fromRGB(14, 14, 14), Color3.fromRGB(10, 10, 10)},
		Rotation = 90,
	},
	TabButton = {
		Enabled = true,
		Color = {Color3.fromRGB(20, 20, 20), Color3.fromRGB(14, 14, 14)},
		Rotation = 90,
	},
	Section = {
		Enabled = true,
		Color = {Color3.fromRGB(22, 22, 22), Color3.fromRGB(16, 16, 16)},
		Rotation = 90,
	},
	AccentButton = {
		Enabled = true,
		Color = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 225, 225)},
		Rotation = 90,
	},
	Input = {
		Enabled = true,
		Color = {Color3.fromRGB(10, 10, 10), Color3.fromRGB(6, 6, 6)},
		Rotation = 90,
	},
	ToggleRow = {
		Enabled = true,
		Color = {Color3.fromRGB(18, 18, 18), Color3.fromRGB(13, 13, 13)},
		Rotation = 90,
	},
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

function Window:_trackConnection(connection)
	table.insert(self._connections, connection)
	return connection
end

function Window:_trackHover(button, stroke, defaultColor, hoverColor)
	self:_trackConnection(button.MouseEnter:Connect(function()
		tween(stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = hoverColor,
		})
	end))

	self:_trackConnection(button.MouseLeave:Connect(function()
		tween(stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

		tween(tab._button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = if isActive then theme.Topbar else theme.Surface,
			TextColor3 = if isActive then theme.Accent else theme.TextMuted,
		})

		tween(tab._buttonStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if isActive then theme.ActiveBorder else theme.Border,
		})
	end

	task.wait()
end

function Window:CreateTab(name)
	if self._destroyed then
		error("Cannot create tab on a destroyed window.", 2)
	end

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
	tabButton.Size = UDim2.new(1, 0, 0, 34)
	tabButton.BackgroundColor3 = theme.Surface
	tabButton.BorderSizePixel = 0
	tabButton.AutoButtonColor = false
	tabButton.Text = tostring(name)
	tabButton.TextColor3 = theme.TextMuted
	tabButton.TextSize = 14
	tabButton.Font = fonts.Code

	local tabButtonStroke = makeStroke(tabButton, theme.Border)
	makeGradient(tabButton, gradients.TabButton, theme.Surface, theme.Background)

	self:_trackConnection(tabButton.MouseEnter:Connect(function()
		if self._activeTab ~= tab then
			tween(tabButtonStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = theme.HoverBorder,
			})
		end
	end))

	self:_trackConnection(tabButton.MouseLeave:Connect(function()
		tween(tabButtonStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if self._activeTab == tab then theme.ActiveBorder else theme.Border,
		})
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
	pagePadding.PaddingTop = UDim.new(0, 12)
	pagePadding.PaddingBottom = UDim.new(0, 12)
	pagePadding.PaddingLeft = UDim.new(0, 12)
	pagePadding.PaddingRight = UDim.new(0, 12)

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Parent = tabPage
	pageLayout.FillDirection = Enum.FillDirection.Vertical
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Padding = UDim.new(0, 8)

	tab._button = tabButton
	tab._buttonStroke = tabButtonStroke
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

function Tab:CreateSection(title)
	local theme = self._window._theme
	local fonts = self._window._fonts
	local gradients = self._window._gradients

	local section = Instance.new("Frame")
	section.Name = "Section_" .. sanitizeName(title, "Section")
	section.Parent = self._page
	section.Size = UDim2.new(1, 0, 0, 36)
	section.BackgroundColor3 = theme.Surface
	section.BorderSizePixel = 0

	makeStroke(section, theme.Border)
	makeGradient(section, gradients.Section, theme.Surface, theme.Background)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = section
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Font = fonts.Header
	label.Text = tostring(title)
	label.TextColor3 = theme.Accent
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Parent = section
	divider.AnchorPoint = Vector2.new(1, 0.5)
	divider.Position = UDim2.new(1, -10, 0.5, 0)
	divider.Size = UDim2.new(0.35, 0, 0, 1)
	divider.BackgroundColor3 = theme.Border
	divider.BorderSizePixel = 0

	return section
end

function Tab:CreateButton(text, callback)
	local theme = self._window._theme
	local fonts = self._window._fonts
	local gradients = self._window._gradients

	local button = Instance.new("TextButton")
	button.Name = "Button_" .. sanitizeName(text, "Button")
	button.Parent = self._page
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = theme.Accent
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = tostring(text)
	button.TextColor3 = theme.ButtonText
	button.TextSize = 14
	button.Font = fonts.Code

	local buttonStroke = makeStroke(button, theme.ButtonBorder)
	makeGradient(button, gradients.AccentButton, theme.Accent, Color3.fromRGB(225, 225, 225))
	self._window:_trackHover(button, buttonStroke, theme.ButtonBorder, theme.HoverBorder)

	self._window:_trackConnection(button.MouseButton1Click:Connect(function()
		tween(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		})
		task.wait(0.05)
		tween(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = theme.Accent,
		})
		safeCallback(callback)
	end))

	return button
end

function Tab:CreateInput(placeholder, callback)
	local theme = self._window._theme
	local fonts = self._window._fonts
	local gradients = self._window._gradients

	local holder = Instance.new("Frame")
	holder.Name = "Input_" .. sanitizeName(placeholder, "Input")
	holder.Parent = self._page
	holder.Size = UDim2.new(1, 0, 0, 38)
	holder.BackgroundColor3 = theme.Inset
	holder.BorderSizePixel = 0
	holder.Active = true

	local holderStroke = makeStroke(holder, theme.Border)
	makeGradient(holder, gradients.Input, theme.Inset, theme.Background)
	self._window:_trackHover(holder, holderStroke, theme.Border, theme.HoverBorder)

	local input = Instance.new("TextBox")
	input.Name = "TextBox"
	input.Parent = holder
	input.BackgroundTransparency = 1
	input.Position = UDim2.new(0, 10, 0, 0)
	input.Size = UDim2.new(1, -20, 1, 0)
	input.Font = fonts.Code
	input.Text = ""
	input.PlaceholderText = tostring(placeholder)
	input.TextColor3 = theme.Accent
	input.PlaceholderColor3 = theme.TextMuted
	input.TextSize = 14
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left

	self._window:_trackConnection(input.Focused:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.ActiveBorder,
		})
	end))

	self._window:_trackConnection(input.FocusLost:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = theme.Border,
		})
		safeCallback(callback, input.Text)
	end))

	return input
end

function Tab:CreateToggle(text, callback)
	local theme = self._window._theme
	local fonts = self._window._fonts
	local gradients = self._window._gradients

	local row = Instance.new("TextButton")
	row.Name = "Toggle_" .. sanitizeName(text, "Toggle")
	row.Parent = self._page
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = theme.Surface
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Text = ""

	local rowStroke = makeStroke(row, theme.Border)
	makeGradient(row, gradients.ToggleRow, theme.Surface, theme.Background)
	self._window:_trackHover(row, rowStroke, theme.Border, theme.HoverBorder)

	local checkbox = Instance.new("Frame")
	checkbox.Name = "Checkbox"
	checkbox.Parent = row
	checkbox.Position = UDim2.new(0, 8, 0.5, -9)
	checkbox.Size = UDim2.new(0, 18, 0, 18)
	checkbox.BackgroundColor3 = theme.Background
	checkbox.BorderSizePixel = 0

	local checkboxStroke = makeStroke(checkbox, theme.Border)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Parent = checkbox
	fill.Position = UDim2.new(0, 3, 0, 3)
	fill.Size = UDim2.new(1, -6, 1, -6)
	fill.BackgroundColor3 = theme.Accent
	fill.BorderSizePixel = 0
	fill.BackgroundTransparency = 1

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = row
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 34, 0, 0)
	label.Size = UDim2.new(1, -42, 1, 0)
	label.Text = tostring(text)
	label.Font = fonts.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = theme.Accent

	local state = false
	local function setState(nextState)
		state = nextState == true
		tween(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = if state then 0 else 1,
		})
		tween(checkboxStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if state then theme.ActiveBorder else theme.Border,
		})
		safeCallback(callback, state)
	end

	self._window:_trackConnection(row.MouseButton1Click:Connect(function()
		setState(not state)
	end))

	return {
		Set = function(_, nextState)
			setState(nextState)
		end,
		Get = function()
			return state
		end,
	}
end

function Library.CreateWindow(options)
	options = options or {}

	local config = mergeTables(BaseConfig, options)
	local theme = mergeTables(BaseTheme, options.Theme)
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
	makeGradient(topbar, gradients.TopBar, theme.Topbar, theme.Surface)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Parent = topbar
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 12, 0, 5)
	titleLabel.Size = UDim2.new(1, -24, 0, 18)
	titleLabel.Text = config.Title
	titleLabel.Font = fonts.Header
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = theme.Accent

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Parent = topbar
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 12, 0, 22)
	subtitleLabel.Size = UDim2.new(1, -24, 0, 16)
	subtitleLabel.Text = config.Subtitle
	subtitleLabel.Font = fonts.Code
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextColor3 = theme.TextMuted

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Parent = main
	body.Position = UDim2.new(0, 0, 0, topbarHeight)
	body.Size = UDim2.new(1, 0, 1, -topbarHeight)
	body.BackgroundColor3 = theme.Background
	body.BorderSizePixel = 0

	makeGradient(body, gradients.Body, theme.Background, theme.Inset)

	local tabRail = Instance.new("Frame")
	tabRail.Name = "TabRail"
	tabRail.Parent = body
	tabRail.Size = UDim2.new(0, tabRailWidth, 1, 0)
	tabRail.BackgroundColor3 = theme.Surface
	tabRail.BorderSizePixel = 0

	makeStroke(tabRail, theme.Border)
	makeGradient(tabRail, gradients.TabRail, theme.Surface, theme.Background)

	local railPadding = Instance.new("UIPadding")
	railPadding.Parent = tabRail
	railPadding.PaddingTop = UDim.new(0, 12)
	railPadding.PaddingBottom = UDim.new(0, 12)
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
	tabListLayout.Padding = UDim.new(0, 6)

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
