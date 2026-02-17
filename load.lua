local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Digital brutalist theme tokens for consistent styling.
local Library = {}

local Theme = {
	Background = Color3.fromRGB(10, 10, 10),
	Surface = Color3.fromRGB(14, 14, 14),
	Topbar = Color3.fromRGB(18, 18, 18),
	Inset = Color3.fromRGB(7, 7, 7),
	Border = Color3.fromRGB(45, 45, 45),
	HoverBorder = Color3.fromRGB(68, 68, 68),
	ActiveBorder = Color3.fromRGB(95, 95, 95),
	Accent = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(165, 165, 165),
}

local Fonts = {
	Header = Enum.Font.GothamBold,
	Code = Enum.Font.Code,
}

local function makeStroke(target: Instance, color: Color3): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	return stroke
end

local function tween(instance: Instance, info: TweenInfo, goals: {[string]: any}): Tween
	local animation = TweenService:Create(instance, info, goals)
	animation:Play()
	return animation
end

local function getGuiParent(customParent: Instance?): Instance
	if customParent then
		return customParent
	end

	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end

	return game:GetService("CoreGui")
end

local function safeCallback(callback: ((...any) -> ())?, ...: any)
	if not callback then
		return
	end

	task.spawn(function(...)
		local ok, err = pcall(callback :: (...any) -> (), ...)
		if not ok then
			warn("[SingularityUI] callback error:", err)
		end
	end, ...)
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

function Window:_trackConnection(connection: RBXScriptConnection)
	table.insert(self._connections, connection)
	return connection
end

function Window:_trackHover(button: GuiObject, stroke: UIStroke, defaultColor: Color3, hoverColor: Color3)
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

function Window:_makeDraggable(handle: GuiObject, target: GuiObject)
	local dragging = false
	local dragInput: InputObject? = nil
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

		local stopConn: RBXScriptConnection
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

	self._activeTab = selected

	for _, tab in ipairs(self._tabs) do
		local isActive = tab == selected
		tab._page.Visible = isActive

		tween(tab._button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = if isActive then Theme.Topbar else Theme.Surface,
			TextColor3 = if isActive then Theme.Accent else Theme.TextMuted,
		})

		tween(tab._buttonStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if isActive then Theme.ActiveBorder else Theme.Border,
		})
	end

	task.wait()
end

function Window:CreateTab(name: string)
	if self._destroyed then
		error("Cannot create tab on a destroyed window.", 2)
	end

	local tab = setmetatable({
		Name = name,
		_window = self,
	}, Tab)

	local tabButton = Instance.new("TextButton")
	tabButton.Name = string.format("Tab_%s", name:gsub("%s+", ""))
	tabButton.Parent = self._tabButtonList
	tabButton.Size = UDim2.new(1, 0, 0, 34)
	tabButton.BackgroundColor3 = Theme.Surface
	tabButton.BorderSizePixel = 0
	tabButton.AutoButtonColor = false
	tabButton.Text = name
	tabButton.TextColor3 = Theme.TextMuted
	tabButton.TextSize = 14
	tabButton.Font = Fonts.Code

	local tabButtonStroke = makeStroke(tabButton, Theme.Border)
	self:_trackConnection(tabButton.MouseEnter:Connect(function()
		if self._activeTab ~= tab then
			tween(tabButtonStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Theme.HoverBorder,
			})
		end
	end))

	self:_trackConnection(tabButton.MouseLeave:Connect(function()
		tween(tabButtonStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if self._activeTab == tab then Theme.ActiveBorder else Theme.Border,
		})
	end))

	local tabPage = Instance.new("ScrollingFrame")
	tabPage.Name = string.format("Page_%s", name:gsub("%s+", ""))
	tabPage.Parent = self._pageContainer
	tabPage.BackgroundColor3 = Theme.Background
	tabPage.BorderSizePixel = 0
	tabPage.Size = UDim2.new(1, 0, 1, 0)
	tabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabPage.ScrollBarThickness = 4
	tabPage.ScrollBarImageColor3 = Theme.Border
	tabPage.Visible = false

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

	-- Quick close animation before teardown.
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

function Tab:CreateSection(title: string)
	local section = Instance.new("Frame")
	section.Name = string.format("Section_%s", title:gsub("%s+", ""))
	section.Parent = self._page
	section.Size = UDim2.new(1, 0, 0, 36)
	section.BackgroundColor3 = Theme.Surface
	section.BorderSizePixel = 0

	makeStroke(section, Theme.Border)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = section
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Font = Fonts.Header
	label.Text = title
	label.TextColor3 = Theme.Accent
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Parent = section
	divider.AnchorPoint = Vector2.new(1, 0.5)
	divider.Position = UDim2.new(1, -10, 0.5, 0)
	divider.Size = UDim2.new(0.35, 0, 0, 1)
	divider.BackgroundColor3 = Theme.Border
	divider.BorderSizePixel = 0

	return section
end

function Tab:CreateButton(text: string, callback: (() -> ())?)
	local button = Instance.new("TextButton")
	button.Name = string.format("Button_%s", text:gsub("%s+", ""))
	button.Parent = self._page
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = Theme.Accent
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = Color3.fromRGB(0, 0, 0)
	button.TextSize = 14
	button.Font = Fonts.Code

	local buttonStroke = makeStroke(button, Color3.fromRGB(20, 20, 20))
	self._window:_trackHover(button, buttonStroke, Color3.fromRGB(20, 20, 20), Color3.fromRGB(60, 60, 60))

	self._window:_trackConnection(button.MouseButton1Click:Connect(function()
		tween(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		})
		task.wait(0.05)
		tween(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Theme.Accent,
		})
		safeCallback(callback)
	end))

	return button
end

function Tab:CreateInput(placeholder: string, callback: ((string) -> ())?)
	local holder = Instance.new("Frame")
	holder.Name = string.format("Input_%s", placeholder:gsub("%s+", ""))
	holder.Parent = self._page
	holder.Size = UDim2.new(1, 0, 0, 38)
	holder.BackgroundColor3 = Theme.Inset
	holder.BorderSizePixel = 0
	holder.Active = true

	local holderStroke = makeStroke(holder, Theme.Border)
	self._window:_trackHover(holder, holderStroke, Theme.Border, Theme.HoverBorder)

	local input = Instance.new("TextBox")
	input.Name = "TextBox"
	input.Parent = holder
	input.BackgroundTransparency = 1
	input.Position = UDim2.new(0, 10, 0, 0)
	input.Size = UDim2.new(1, -20, 1, 0)
	input.Font = Fonts.Code
	input.Text = ""
	input.PlaceholderText = placeholder
	input.TextColor3 = Theme.Accent
	input.PlaceholderColor3 = Theme.TextMuted
	input.TextSize = 14
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left

	self._window:_trackConnection(input.Focused:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.ActiveBorder,
		})
	end))

	self._window:_trackConnection(input.FocusLost:Connect(function()
		tween(holderStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.Border,
		})
		safeCallback(callback, input.Text)
	end))

	return input
end

function Tab:CreateToggle(text: string, callback: ((boolean) -> ())?)
	local row = Instance.new("TextButton")
	row.Name = string.format("Toggle_%s", text:gsub("%s+", ""))
	row.Parent = self._page
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Theme.Surface
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Text = ""

	local rowStroke = makeStroke(row, Theme.Border)
	self._window:_trackHover(row, rowStroke, Theme.Border, Theme.HoverBorder)

	local checkbox = Instance.new("Frame")
	checkbox.Name = "Checkbox"
	checkbox.Parent = row
	checkbox.Position = UDim2.new(0, 8, 0.5, -9)
	checkbox.Size = UDim2.new(0, 18, 0, 18)
	checkbox.BackgroundColor3 = Theme.Background
	checkbox.BorderSizePixel = 0

	local checkboxStroke = makeStroke(checkbox, Theme.Border)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Parent = checkbox
	fill.Position = UDim2.new(0, 3, 0, 3)
	fill.Size = UDim2.new(1, -6, 1, -6)
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.BackgroundTransparency = 1

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = row
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 34, 0, 0)
	label.Size = UDim2.new(1, -42, 1, 0)
	label.Text = text
	label.Font = Fonts.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Accent

	local state = false
	local function setState(nextState: boolean)
		state = nextState
		tween(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = if state then 0 else 1,
		})
		tween(checkboxStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if state then Theme.ActiveBorder else Theme.Border,
		})
		safeCallback(callback, state)
	end

	self._window:_trackConnection(row.MouseButton1Click:Connect(function()
		setState(not state)
	end))

	local toggleApi = {
		Set = function(_, nextState: boolean)
			setState(nextState)
		end,
		Get = function()
			return state
		end,
	}

	return toggleApi
end

function Library.CreateWindow(options)
	options = options or {}

	local title = options.Title or "SINGULARITY UI"
	local subtitle = options.Subtitle or "SYSTEM CONTROL"
	local targetSize = options.Size or UDim2.fromOffset(780, 500)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = options.Name or "SingularityWindow"
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = getGuiParent(options.Parent)

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Parent = screenGui
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = options.Position or UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.new(targetSize.X.Scale, targetSize.X.Offset, 0, 0)
	main.BackgroundColor3 = Theme.Background
	main.BorderSizePixel = 0

	makeStroke(main, Theme.Border)

	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Parent = main
	topbar.Size = UDim2.new(1, 0, 0, 44)
	topbar.BackgroundColor3 = Theme.Topbar
	topbar.BorderSizePixel = 0
	topbar.Active = true

	makeStroke(topbar, Theme.Border)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Parent = topbar
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 12, 0, 5)
	titleLabel.Size = UDim2.new(1, -24, 0, 18)
	titleLabel.Text = title
	titleLabel.Font = Fonts.Header
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Accent

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Parent = topbar
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 12, 0, 22)
	subtitleLabel.Size = UDim2.new(1, -24, 0, 16)
	subtitleLabel.Text = subtitle
	subtitleLabel.Font = Fonts.Code
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextColor3 = Theme.TextMuted

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Parent = main
	body.Position = UDim2.new(0, 0, 0, 44)
	body.Size = UDim2.new(1, 0, 1, -44)
	body.BackgroundColor3 = Theme.Background
	body.BorderSizePixel = 0

	local tabRail = Instance.new("Frame")
	tabRail.Name = "TabRail"
	tabRail.Parent = body
	tabRail.Size = UDim2.new(0, 170, 1, 0)
	tabRail.BackgroundColor3 = Theme.Surface
	tabRail.BorderSizePixel = 0

	makeStroke(tabRail, Theme.Border)

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
	pageContainer.Position = UDim2.new(0, 170, 0, 0)
	pageContainer.Size = UDim2.new(1, -170, 1, 0)
	pageContainer.BackgroundColor3 = Theme.Background
	pageContainer.BorderSizePixel = 0

	makeStroke(pageContainer, Theme.Border)

	local window = setmetatable({
		_screenGui = screenGui,
		_main = main,
		_targetSize = targetSize,
		_tabButtonList = tabButtonList,
		_pageContainer = pageContainer,
		_tabs = {},
		_activeTab = nil,
		_connections = {},
		_destroyed = false,
	}, Window)

	window:_makeDraggable(topbar, main)

	tween(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
	})
	task.wait(0.03)

	return window
end

return Library
