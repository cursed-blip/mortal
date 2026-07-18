--[[
	Mortal UI - a self-contained Roblox UI library.
	Distinct layout: left icon rail + center card column + right info panel.
	Public API mirrors the previous build so existing scripts keep working.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HTTPService = game:GetService("HttpService")

local Library = {
	Themes = {
		Noir = {
			Main = Color3.fromRGB(18, 18, 22),
			Secondary = Color3.fromRGB(30, 30, 38),
			Tertiary = Color3.fromRGB(124, 92, 255),
			StrongText = Color3.fromRGB(240, 240, 248),
			WeakText = Color3.fromRGB(150, 150, 165)
		},
		Aurora = {
			Main = Color3.fromRGB(14, 22, 30),
			Secondary = Color3.fromRGB(24, 38, 52),
			Tertiary = Color3.fromRGB(56, 189, 248),
			StrongText = Color3.fromRGB(236, 248, 255),
			WeakText = Color3.fromRGB(140, 165, 185)
		},
		Ember = {
			Main = Color3.fromRGB(26, 16, 16),
			Secondary = Color3.fromRGB(42, 26, 26),
			Tertiary = Color3.fromRGB(255, 122, 89),
			StrongText = Color3.fromRGB(255, 240, 235),
			WeakText = Color3.fromRGB(180, 150, 145)
		},
		Mono = {
			Main = Color3.fromRGB(22, 22, 22),
			Secondary = Color3.fromRGB(38, 38, 38),
			Tertiary = Color3.fromRGB(232, 232, 232),
			StrongText = Color3.fromRGB(245, 245, 245),
			WeakText = Color3.fromRGB(150, 150, 150)
		},
		Moss = {
			Main = Color3.fromRGB(16, 24, 18),
			Secondary = Color3.fromRGB(28, 42, 32),
			Tertiary = Color3.fromRGB(132, 204, 22),
			StrongText = Color3.fromRGB(238, 248, 238),
			WeakText = Color3.fromRGB(150, 175, 152)
		}
	},
	ColorPickerStyles = {
		Legacy = 0,
		Modern = 1
	},
	Toggled = true,
	ThemeObjects = {
		Main = {},
		Secondary = {},
		Tertiary = {},
		StrongText = {},
		WeakText = {}
	},
	DragSpeed = 0.06,
	LockDragging = false,
	ToggleKey = Enum.KeyCode.Home
}

Library.__index = Library

local GlobalTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Library:set_defaults(defaults, options)
	defaults = defaults or {}
	options = options or {}
	for option, value in next, options do
		defaults[option] = value
	end
	return defaults
end

function Library:darken(color, f)
	local h, s, v = Color3.toHSV(color)
	f = 1 - ((f or 15) / 80)
	return Color3.fromHSV(h, math.clamp(s / f, 0, 1), math.clamp(v * f, 0, 1))
end

function Library:lighten(color, f)
	local h, s, v = Color3.toHSV(color)
	f = 1 - ((f or 15) / 80)
	return Color3.fromHSV(h, math.clamp(s * f, 0, 1), math.clamp(v / f, 0, 1))
end

function Library:object(class, properties)
	local localObject = Instance.new(class)

	local forcedProps = {
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.Gotham,
		Text = ""
	}

	for property, value in next, forcedProps do
		pcall(function()
			localObject[property] = value
		end)
	end

	local methods = {}
	methods.AbsoluteObject = localObject

	function methods:tween(options, callback)
		local options = Library:set_defaults({
			Length = 0.2,
			Style = Enum.EasingStyle.Quad,
			Direction = Enum.EasingDirection.Out
		}, options)
		callback = callback or function() return end

		local ti = TweenInfo.new(options.Length, options.Style, options.Direction)
		options.Length = nil
		options.Style = nil
		options.Direction = nil

		local tween = TweenService:Create(localObject, ti, options)
		tween:Play()
		tween.Completed:Connect(callback)
		return tween
	end

	function methods:round(radius)
		radius = radius or 8
		Library:object("UICorner", {
			Parent = localObject,
			CornerRadius = UDim.new(0, radius)
		})
		return methods
	end

	function methods:object(class, properties)
		local properties = properties or {}
		properties.Parent = localObject
		return Library:object(class, properties)
	end

	function methods:stroke(color, thickness, strokeMode)
		thickness = thickness or 1
		strokeMode = strokeMode or Enum.ApplyStrokeMode.Border
		local stroke = self:object("UIStroke", {
			ApplyStrokeMode = strokeMode,
			Thickness = thickness
		})

		if type(color) == "table" then
			local theme, colorAlter = color[1], color[2] or 0
			local themeColor = Library.CurrentTheme[theme]
			local modifiedColor = themeColor
			if colorAlter < 0 then
				modifiedColor = Library:darken(themeColor, -1 * colorAlter)
			elseif colorAlter > 0 then
				modifiedColor = Library:lighten(themeColor, colorAlter)
			end
			stroke.Color = modifiedColor
			table.insert(Library.ThemeObjects[theme], {stroke, "Color", theme, colorAlter})
		elseif type(color) == "string" then
			stroke.Color = Library.CurrentTheme[color]
			table.insert(Library.ThemeObjects[color], {stroke, "Color", color, 0})
		else
			stroke.Color = color
		end
		return methods
	end

	function methods:tooltip(text)
		local tip = methods:object("TextLabel", {
			Theme = {BackgroundColor3 = {"Main", 12}, TextColor3 = "StrongText"},
			TextSize = 13,
			Text = text,
			Position = UDim2.new(1, 8, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			TextTransparency = 1,
			ZIndex = 50
		}):round(6)
		tip.Size = UDim2.fromOffset(tip.TextBounds.X + 16, tip.TextBounds.Y + 8)

		local hovered = false
		methods.MouseEnter:connect(function()
			hovered = true
			wait(0.25)
			if hovered then
				tip:tween{BackgroundTransparency = 0.1, TextTransparency = 0, Length = 0.15}
			end
		end)
		methods.MouseLeave:connect(function()
			hovered = false
			tip:tween{BackgroundTransparency = 1, TextTransparency = 1, Length = 0.15}
		end)
		return methods
	end

	local customHandlers = {
		Centered = function(value)
			if value then
				localObject.AnchorPoint = Vector2.new(0.5, 0.5)
				localObject.Position = UDim2.fromScale(0.5, 0.5)
			end
		end,
		Theme = function(value)
			for property, obj in next, value do
				if type(obj) == "table" then
					local theme, colorAlter = obj[1], obj[2] or 0
					local themeColor = Library.CurrentTheme[theme]
					local modifiedColor = themeColor
					if colorAlter < 0 then
						modifiedColor = Library:darken(themeColor, -1 * colorAlter)
					elseif colorAlter > 0 then
						modifiedColor = Library:lighten(themeColor, colorAlter)
					end
					localObject[property] = modifiedColor
					table.insert(Library.ThemeObjects[theme], {methods, property, theme, colorAlter})
				else
					localObject[property] = Library.CurrentTheme[obj]
					table.insert(Library.ThemeObjects[obj], {methods, property, obj, 0})
				end
			end
		end
	}

	for property, value in next, properties do
		if customHandlers[property] then
			customHandlers[property](value)
		else
			localObject[property] = value
		end
	end

	return setmetatable(methods, {
		__index = function(_, property)
			return localObject[property]
		end,
		__newindex = function(_, property, value)
			localObject[property] = value
		end
	})
end

function Library:change_theme(toTheme)
	Library.CurrentTheme = toTheme
	for color, objects in next, Library.ThemeObjects do
		local themeColor = Library.CurrentTheme[color]
		for _, obj in next, objects do
			local element, property, theme, colorAlter = obj[1], obj[2], obj[3], obj[4] or 0
			local base = Library.CurrentTheme[theme]
			local modifiedColor = base
			if colorAlter < 0 then
				modifiedColor = Library:darken(base, -1 * colorAlter)
			elseif colorAlter > 0 then
				modifiedColor = Library:lighten(base, colorAlter)
			end
			element:tween{[property] = modifiedColor, Length = 0.25}
		end
	end
end

function Library:set_status(txt)
	if self.statusText then
		self.statusText.Text = "Status | " .. tostring(txt)
	end
end

function Library:_resize_tab()
	if not self.layout then return end
	if self.container and self.container.ClassName == "ScrollingFrame" then
		self.container.CanvasSize = UDim2.fromOffset(0, self.layout.AbsoluteContentSize.Y + 20)
	elseif self.sectionContainer and self.parentContainer then
		self.sectionContainer.Size = UDim2.new(1, -16, 0, self.layout.AbsoluteContentSize.Y + 20)
		self.parentContainer.CanvasSize = UDim2.fromOffset(0, self.parentLayout.AbsoluteContentSize.Y + 20)
	end
end

-- hover helper for cards
local function bindCardHover(card, secondary)
	local hovered, down = false, false
	card.MouseEnter:connect(function()
		hovered = true
		card:tween{BackgroundColor3 = Library:lighten(secondary, 8)}
	end)
	card.MouseLeave:connect(function()
		hovered = false
		if not down then card:tween{BackgroundColor3 = secondary} end
	end)
	card.MouseButton1Down:connect(function()
		down = true
		card:tween{BackgroundColor3 = Library:lighten(secondary, 16)}
	end)
	UserInputService.InputEnded:connect(function(key)
		if key.UserInputType == Enum.UserInputType.MouseButton1 then
			down = false
			card:tween{BackgroundColor3 = (hovered and Library:lighten(secondary, 8)) or secondary}
		end
	end)
end

function Library:create(options)
	local settings = { Theme = "Noir" }
	if readfile and writefile and isfile then
		if not isfile("MortalSettings.json") then
			writefile("MortalSettings.json", HTTPService:JSONEncode(settings))
		end
		settings = HTTPService:JSONDecode(readfile("MortalSettings.json"))
		updateSettings = function(property, value)
			settings[property] = value
			writefile("MortalSettings.json", HTTPService:JSONEncode(settings))
		end
	end
	local updateSettings = updateSettings or function() end

	if not Library.Themes[settings.Theme] then settings.Theme = "Noir" end
	Library.CurrentTheme = Library.Themes[settings.Theme]

	options = self:set_defaults({
		Name = "Mortal",
		Size = UDim2.fromOffset(640, 430),
		Theme = Library.CurrentTheme,
		Link = "https://github.com/madium/mortal-lib"
	}, options)

	if getgenv and getgenv().MortalUI then
		getgenv():MortalUI()
		getgenv().MortalUI = nil
	end

	self.CurrentTheme = options.Theme

	local gui = self:object("ScreenGui", {
		Parent = (RunService:IsStudio() and LocalPlayer.PlayerGui) or game:GetService("CoreGui"),
		ZIndexBehavior = Enum.ZIndexBehavior.Global
	})

	-- notifications
	local notificationHolder = gui:object("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0, 300, 1, -48)
	})
	notificationHolder:object("UIListLayout", {
		Padding = UDim.new(0, 14),
		VerticalAlignment = Enum.VerticalAlignment.Bottom
	})

	-- watermark
	local watermark = gui:object("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(0, 240, 0, 18),
		Font = Enum.Font.GothamMedium,
		Text = "Mortal UI  ·  " .. options.Name,
		Theme = {TextColor3 = "WeakText"},
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.7
	})
	local wp
	wp = RunService.Heartbeat:Connect(function()
		if not watermark.Parent then wp:Disconnect() return end
		local t = tick() % 3
		watermark.TextTransparency = 0.5 + 0.25 * (0.5 + 0.5 * math.sin(t * math.pi))
	end)

	-- main window
	local core = gui:object("Frame", {
		Size = UDim2.new(),
		Theme = {BackgroundColor3 = {"Main", -4}},
		Centered = true,
		ClipsDescendants = true,
		BackgroundTransparency = 0.08
	}):round(16):stroke("Tertiary", 1)

	core:tween({Size = options.Size, Length = 0.35}, function()
		core.ClipsDescendants = false
	end)

	rawset(core, "oldSize", options.Size)
	self.mainFrame = core

	-- LEFT ICON RAIL
	local rail = core:object("Frame", {
		Size = UDim2.new(0, 56, 1, 0),
		Position = UDim2.fromScale(0, 0),
		Theme = {BackgroundColor3 = {"Main", -10}},
		BackgroundTransparency = 0.25
	})
	rail:object("UICorner", { CornerRadius = UDim.new(0, 16) })

	local railList = rail:object("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8)
	})
	rail:object("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) })

	-- CENTER CONTENT
	local content = core:object("ScrollingFrame", {
		Theme = {BackgroundColor3 = {"Secondary", -8}},
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 56, 0, 0),
		Size = UDim2.new(1, -56 - 150, 1, -40),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BackgroundTransparency = 0.3
	}):round(0)
	content.ScrollBarImageColor3 = Library.CurrentTheme.Tertiary
	local contentLayout = content:object("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder
	})
	content:object("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14) })

	-- RIGHT INFO PANEL
	local side = core:object("Frame", {
		Size = UDim2.new(0, 150, 1, -40),
		Position = UDim2.new(1, -150, 0, 0),
		Theme = {BackgroundColor3 = {"Main", -8}},
		BackgroundTransparency = 0.25
	})
	local sideList = side:object("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder
	})
	side:object("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14) })

	-- TITLE BAR (bottom strip)
	local titleBar = core:object("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		Theme = {BackgroundColor3 = {"Main", -12}},
		BackgroundTransparency = 0.2
	})
	local status = titleBar:object("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.new(0.6, 0, 0, 18),
		Font = Enum.Font.Gotham,
		Text = "Status | Idle",
		Theme = {TextColor3 = "Tertiary"},
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local function makeTitleButton(iconId, pos, color)
		local b = titleBar:object("ImageButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(16, 16),
			Position = pos,
			Theme = {ImageColor3 = "StrongText"},
			Image = iconId,
			AnchorPoint = Vector2.new(1, 0.5)
		})
		b.MouseEnter:connect(function() b:tween{ImageColor3 = color} end)
		b.MouseLeave:connect(function() b:tween{ImageColor3 = Library.CurrentTheme.StrongText} end)
		return b
	end

	local closeBtn = makeTitleButton("rbxassetid://8497487650", UDim2.new(1, -12, 0.5, 0), Color3.fromRGB(255, 124, 142))
	local miniBtn = makeTitleButton("rbxassetid://8498687508", UDim2.new(1, -36, 0.5, 0), Color3.fromRGB(255, 214, 121))

	local function closeUI()
		core:tween({Size = UDim2.new(), BackgroundTransparency = 1, Length = 0.25}, function()
			gui.AbsoluteObject:Destroy()
		end)
	end
	if getgenv then getgenv().MortalUI = closeUI end
	closeBtn.MouseButton1Click:connect(closeUI)

	local minimized
	miniBtn.MouseButton1Click:connect(function()
		if not minimized then
			rawset(core, "oldSize", core.Size)
			core:tween({Size = UDim2.fromOffset(56, 40), Length = 0.25})
			minimized = true
		else
			core:tween({Size = core.oldSize, Length = 0.25})
			minimized = false
		end
	end)

	-- DRAG
	do
		local S, Event = pcall(function() return core.MouseEnter end)
		if S then
			core.Active = true
			Event:connect(function()
				local Input = core.InputBegan:connect(function(Key)
					if Key.UserInputType == Enum.UserInputType.MouseButton1 and Mouse.X < core.AbsolutePosition.X + 56 then
						local off = Vector2.new(Mouse.X - core.AbsolutePosition.X, Mouse.Y - core.AbsolutePosition.Y)
						while RunService.RenderStepped:wait() and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
							local fx, fy
							if Library.LockDragging then
								fx = math.clamp(Mouse.X - off.X, 0, gui.AbsoluteSize.X - core.AbsoluteSize.X)
								fy = math.clamp(Mouse.Y - off.Y, 0, gui.AbsoluteSize.Y - core.AbsoluteSize.Y)
							else
								fx, fy = Mouse.X - off.X, Mouse.Y - off.Y
							end
							core:tween{Position = UDim2.fromOffset(fx + core.Size.X.Offset * 0.5, fy + core.Size.Y.Offset * 0.5), Length = Library.DragSpeed}
						end
					end
				end)
				local Leave
				Leave = core.MouseLeave:connect(function()
					Input:disconnect(); Leave:disconnect()
				end)
			end)
		end
	end

	-- HOME PAGE
	local homePage = content:object("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y
	})
	local homeLayout = homePage:object("UIListLayout", {
		Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center
	})

	local profile = homePage:object("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		Theme = {BackgroundColor3 = {"Secondary", 6}},
		BackgroundTransparency = 0.15
	}):round(12):stroke("Tertiary", 1)
	local pfp = profile:object("ImageLabel", {
		Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(72, 72)
	}):round(36)
	local dispName = profile:object("TextLabel", {
		RichText = true,
		Text = "Welcome, <b>" .. LocalPlayer.DisplayName .. "</b>",
		TextScaled = true,
		Position = UDim2.new(0, 98, 0.18, 0),
		Theme = {TextColor3 = "StrongText"},
		Size = UDim2.new(1, -120, 0, 30),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local userName = profile:object("TextLabel", {
		Text = "@" .. LocalPlayer.Name,
		TextScaled = true,
		Position = UDim2.new(0, 98, 0.55, 0),
		Theme = {TextColor3 = "WeakText"},
		Size = UDim2.new(1, -120, 0, 18),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local clock = profile:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 98, 0.82, 0),
		Size = UDim2.new(1, -120, 0, 14),
		Theme = {TextColor3 = {"Tertiary", 10}},
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(os.date("%X")):sub(1, -4)
	})
	RunService.Heartbeat:Connect(function(step)
		if not clock.Parent then return end
		local d = tostring(os.date("%X"))
		clock.Text = d:sub(1, -4)
	end)

	local settingsIcon = profile:object("ImageButton", {
		BackgroundTransparency = 1,
		Theme = {ImageColor3 = "WeakText"},
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		Image = "rbxassetid://8559790237"
	}):tooltip("settings")
	local creditsIcon = profile:object("ImageButton", {
		BackgroundTransparency = 1,
		Theme = {ImageColor3 = "WeakText"},
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -46, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		Image = "rbxassetid://8577523456"
	}):tooltip("credits")

	-- RIGHT SIDE: quick stats
	local infoCard = side:object("Frame", {
		Size = UDim2.new(1, 0, 0, 90),
		Theme = {BackgroundColor3 = {"Secondary", 4}},
		BackgroundTransparency = 0.2
	}):round(12):stroke("Tertiary", 1)
	infoCard:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.GothamMedium,
		Text = "Session",
		Theme = {TextColor3 = "Tertiary"},
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local fpsLabel = infoCard:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "FPS: --",
		Theme = {TextColor3 = "StrongText"},
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local memLabel = infoCard:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "Mem: -- MB",
		Theme = {TextColor3 = "WeakText"},
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local frames, lastT = 0, tick()
	RunService.Heartbeat:Connect(function()
		if not fpsLabel.Parent then return end
		frames += 1
		local now = tick()
		if now - lastT >= 1 then
			fpsLabel.Text = "FPS: " .. frames
			memLabel.Text = "Mem: " .. math.floor(collectgarbage("count") / 1024) .. " MB"
			frames = 0; lastT = now
		end
	end)

	local tabs = {}
	local selectedTab
	local railButtons = {}

	local function selectTab(tabInfo)
		local page, railBtn, name = tabInfo[1], tabInfo[2], tabInfo[3]
		for _, t in next, tabs do
			t[1].Visible = false
			t[2]:tween{BackgroundColor3 = Library:darken(Library.CurrentTheme.Main, 12)}
		end
		page.Visible = true
		railBtn:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary}
		selectedTab = tabInfo
		status.Text = "Status | " .. (name or "home")
	end

	-- HOME rail button
	local homeRail = rail:object("TextButton", {
		BackgroundTransparency = 1,
		Theme = {BackgroundColor3 = "Tertiary"},
		Size = UDim2.new(0, 40, 0, 40),
		Visible = true
	}):round(12)
	homeRail:object("ImageLabel", {
		BackgroundTransparency = 1,
		Centered = true,
		Size = UDim2.fromOffset(22, 22),
		Image = "rbxassetid://8569322835",
		ImageColor3 = Library.CurrentTheme.StrongText
	})
	homeRail.MouseButton1Click:Connect(function()
		homePage.Visible = true
		for _, t in next, tabs do t[1].Visible = false; t[2]:tween{BackgroundColor3 = Library:darken(Library.CurrentTheme.Main, 12)} end
		homeRail:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary}
		selectedTab = nil
		status.Text = "Status | home"
	end)
	table.insert(railButtons, homeRail)

	local mt = setmetatable({
		core = core,
		notifs = notificationHolder,
		statusText = status,
		container = content,
		navigation = rail,
		Theme = options.Theme,
		Tabs = tabs,
		homePage = homePage,
		selectTab = selectTab,
		railList = railList,
		nilFolder = core:object("Folder")
	}, Library)

	-- SETTINGS TAB
	local settingsTab = Library.tab(mt, {
		Name = "Settings",
		Internal = settingsIcon,
		Icon = "rbxassetid://8559790237"
	})
	settingsTab:_theme_selector()
	settingsTab:keybind{
		Name = "Toggle Key",
		Description = "Key to show/hide the UI.",
		Keybind = Enum.KeyCode.Delete,
		Callback = function()
			self.Toggled = not self.Toggled
			Library:show(self.Toggled)
		end
	}
	settingsTab:toggle{
		Name = "Lock Dragging",
		Description = "Keep the window inside the screen.",
		StartingState = true,
		Callback = function(state) Library.LockDragging = state end
	}
	settingsTab:slider{
		Name = "Drag Smoothing",
		Description = "How smooth dragging looks.",
		Max = 20, Default = 14,
		Callback = function(value) Library.DragSpeed = (20 - value) / 100 end
	}

	local creditsTab = Library.tab(mt, {
		Name = "Credits",
		Internal = creditsIcon,
		Icon = "rbxassetid://8577523456"
	})
	rawset(mt, "creditsContainer", creditsTab.container)
	creditsTab:credit{Name = "Madium", Description = "UI Library Developer", Discord = "Madium#0001"}
	creditsTab:credit{Name = "Repository", Description = "Source", Github = "https://github.com/madium/mortal-lib"}

	-- wire settings/credits icons
	settingsIcon.MouseButton1Click:Connect(function() mt:selectTab(tabs[1]) end)
	creditsIcon.MouseButton1Click:Connect(function() mt:selectTab(tabs[#tabs]) end)

	return mt
end

function Library:show(state)
	self.Toggled = state
	if state then
		self.mainFrame.Visible = true
		self.mainFrame:tween({Size = self.mainFrame.oldSize, Length = 0.25})
	else
		self.mainFrame:tween({Size = UDim2.fromOffset(56, 40), Length = 0.25}, function()
			self.mainFrame.Visible = false
		end)
	end
end

function Library:tab(options)
	options = self:set_defaults({
		Name = "New Tab",
		Icon = "rbxassetid://8569322835"
	}, options)

	local tab = self.container:object("ScrollingFrame", {
		Visible = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y
	})
	tab.ScrollBarImageColor3 = Library.CurrentTheme.Tertiary
	local layout = tab:object("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center
	})
	tab:object("UIPadding", { PaddingTop = UDim.new(0, 6) })

	local railBtn
	if options.Internal then
		railBtn = options.Internal
		railBtn.BackgroundColor3 = Library:darken(Library.CurrentTheme.Main, 12)
		railBtn:tween{BackgroundColor3 = Library:darken(Library.CurrentTheme.Main, 12)}
		local ic = railBtn:FindFirstChildOfClass("ImageLabel")
		if ic then ic.Image = options.Icon end
		railBtn.MouseButton1Click:Connect(function() self:selectTab(self.Tabs[#self.Tabs]) end)
	else
		railBtn = self.navigation:object("TextButton", {
			BackgroundTransparency = 1,
			Theme = {BackgroundColor3 = {"Main", -12}},
			Size = UDim2.new(0, 40, 0, 40)
		}):round(12):tooltip(options.Name)
		railBtn:object("ImageLabel", {
			BackgroundTransparency = 1,
			Centered = true,
			Size = UDim2.fromOffset(22, 22),
			Image = options.Icon,
			ImageColor3 = Library.CurrentTheme.StrongText
		})
		railBtn.MouseButton1Click:Connect(function()
			self:selectTab(self.Tabs[#self.Tabs])
		end)
	end

	self.Tabs[#self.Tabs + 1] = {tab, railBtn, options.Name}

	local functionContainer = tab
	return setmetatable({
		statusText = self.statusText,
		container = functionContainer,
		sectionContainer = nil,
		parentContainer = nil,
		Theme = self.Theme,
		core = self.core,
		layout = layout,
		parentLayout = layout
	}, Library)
end

-- CARD wrapper used by every component
function Library:_card(name, description, height)
	local card = self.container:object("Frame", {
		Theme = {BackgroundColor3 = "Secondary"},
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 0.2
	}):round(12):stroke("Tertiary", 1)
	card:object("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		Theme = {BackgroundColor3 = "Tertiary"},
		BackgroundTransparency = 0.1
	}):round(100)
	local title = card:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, description and 8 or (height / 2 - 11)),
		Size = UDim2.new(0.55, -12, 0, 22),
		Text = name,
		TextSize = 17,
		Font = Enum.Font.GothamMedium,
		Theme = {TextColor3 = "StrongText"},
		TextXAlignment = Enum.TextXAlignment.Left
	})
	if description then
		card:object("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(0.55, -12, 0, 18),
			Text = description,
			TextSize = 13,
			Theme = {TextColor3 = "WeakText"},
			TextXAlignment = Enum.TextXAlignment.Left
		})
	end
	bindCardHover(card, Library.CurrentTheme.Secondary)
	self:_resize_tab()
	return card
end

function Library:button(options)
	options = self:set_defaults({ Name = "Button", Description = nil, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local btn = card:object("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(90, 32),
		Theme = {BackgroundColor3 = "Tertiary"},
		Text = "RUN",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Theme2 = nil
	}):round(8)
	btn:object("UICorner", { CornerRadius = UDim.new(0, 8) })
	btn.TextColor3 = Library.CurrentTheme.Main
	local hovered, down = false, false
	btn.MouseEnter:connect(function() hovered = true; btn:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Tertiary, 12)} end)
	btn.MouseLeave:connect(function() hovered = false; if not down then btn:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary} end end)
	btn.MouseButton1Down:connect(function() down = true; btn:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Tertiary, 24)} end)
	UserInputService.InputEnded:connect(function(k)
		if k.UserInputType == Enum.UserInputType.MouseButton1 then down = false; btn:tween{BackgroundColor3 = (hovered and Library:lighten(Library.CurrentTheme.Tertiary, 12)) or Library.CurrentTheme.Tertiary} end
	end)
	btn.MouseButton1Click:connect(function() options.Callback() end)

	local methods = {}
	function methods:Fire() options.Callback() end
	function methods:SetText(t) card:FindFirstChildOfClass("TextLabel").Text = t end
	return methods
end

function Library:toggle(options)
	options = self:set_defaults({ Name = "Toggle", StartingState = false, Description = nil, Callback = function(s) end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local toggled = options.StartingState
	local sw = card:object("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		Theme = {BackgroundColor3 = {"Secondary", -20}},
	}):round(100)
	local knob = sw:object("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, toggled and 34 or 12, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	}):round(100)

	local function paint()
		sw:tween{BackgroundColor3 = toggled and Library.CurrentTheme.Tertiary or Library:darken(Library.CurrentTheme.Secondary, 20)}
		knob:tween{Position = UDim2.new(0, toggled and 34 or 12, 0.5, 0), Length = 0.2}
	end
	paint()
	sw.MouseButton1Click:connect(function()
		toggled = not toggled; paint(); options.Callback(toggled)
	end)

	local methods = {}
	function methods:Toggle() toggled = not toggled; paint(); options.Callback(toggled) end
	function methods:SetState(s) toggled = s; paint(); task.spawn(options.Callback, toggled) end
	if options.StartingState then methods:SetState(true) end
	return methods
end

function Library:slider(options)
	options = self:set_defaults({ Name = "Slider", Default = 50, Min = 0, Max = 100, Description = nil, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 64)
	local valLabel = card:object("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(60, 22),
		Text = tostring(options.Default),
		Theme = {TextColor3 = "Tertiary"},
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right
	})
	local bar = card:object("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1, -24, 0, 6),
		Position = UDim2.new(0.5, 0, 1, -14),
		Theme = {BackgroundColor3 = {"Secondary", -22}}
	}):round(100)
	local fill = bar:object("Frame", {
		Size = UDim2.fromScale((options.Default - options.Min) / (options.Max - options.Min), 1),
		Theme = {BackgroundColor3 = "Tertiary"}
	}):round(100)
	local knob = fill:object("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Library.CurrentTheme.StrongText
	}):round(100)

	local down = false
	card.MouseButton1Down:connect(function()
		down = true
		while RunService.RenderStepped:wait() and down do
			local pct = math.clamp((Mouse.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			local val = math.floor((options.Max - options.Min) * pct + options.Min)
			valLabel.Text = tostring(val)
			fill:tween{Size = UDim2.fromScale(pct, 1), Length = 0.05}
			options.Callback(val)
		end
	end)
	UserInputService.InputEnded:connect(function(k)
		if k.UserInputType == Enum.UserInputType.MouseButton1 then down = false end
	end)

	local methods = {}
	function methods:Set(v) fill:tween{Size = UDim2.fromScale((v - options.Min) / (options.Max - options.Min), 1)}; valLabel.Text = tostring(v) end
	return methods
end

function Library:dropdown(options)
	options = self:set_defaults({ Name = "Dropdown", StartingText = "Select...", Items = {}, Description = nil, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local open = false
	local display = card:object("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 32),
		Theme = {BackgroundColor3 = {"Secondary", -18}, TextColor3 = "StrongText"},
		Text = options.StartingText,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center
	}):round(8)
	local list = card:object("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -44),
		Size = UDim2.fromOffset(150, 0),
		Theme = {BackgroundColor3 = {"Main", -6}},
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20
	}):round(8):stroke("Tertiary", 1)
	local llist = list:object("UIListLayout", { Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Vertical })
	list:object("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

	local items = {}
	for i, v in next, options.Items do
		items[i] = (typeof(v) == "table") and v or {tostring(v), v}
	end

	local function rebuild()
		for _, c in next, list:GetChildren() do if c:IsA("TextButton") then c:Destroy() end end
		for _, it in next, items do
			local row = list:object("TextButton", {
				Size = UDim2.new(1, 0, 0, 24),
				Theme = {BackgroundColor3 = {"Secondary", 8}, TextColor3 = "StrongText"},
				Text = it[1], TextSize = 13, ZIndex = 21
			}):round(6)
			row.MouseEnter:connect(function() row:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary} end)
			row.MouseLeave:connect(function() row:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Secondary, 8)} end)
			row.MouseButton1Click:connect(function()
				display.Text = it[1]
				options.Callback(it[2])
				open = false; list:tween{Size = UDim2.fromOffset(150, 0), Length = 0.15}; list.Visible = false
			end)
		end
		list.CanvasSize = UDim2.fromOffset(0, #items * 28 + 12)
	end
	rebuild()

	display.MouseButton1Click:connect(function()
		open = not open
		if open then
			list.Visible = true
			list:tween{Size = UDim2.fromOffset(150, math.min(#items * 28 + 12, 140)), Length = 0.15}
		else
			list:tween{Size = UDim2.fromOffset(150, 0), Length = 0.15, function() list.Visible = false end}
		end
	end)

	local methods = {}
	function methods:Set(t) display.Text = t end
	function methods:AddItems(f)
		for _, v in next, f do items[#items + 1] = (typeof(v) == "table") and v or {tostring(v), v} end
		rebuild()
	end
	function methods:RemoveItems(f)
		for _, r in next, f do
			for i, it in next, items do
				if it[1]:lower() == tostring(r):lower() then table.remove(items, i) end
			end
		end
		rebuild()
	end
	function methods:Clear() table.clear(items); rebuild(); display.Text = options.StartingText end
	return methods
end

function Library:textbox(options)
	options = self:set_defaults({ Name = "Text Box", Placeholder = "Type...", Description = nil, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local box = card:object("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(160, 32),
		Theme = {BackgroundColor3 = {"Secondary", -18}, TextColor3 = "StrongText"},
		PlaceholderText = options.Placeholder,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClipsDescendants = true
	}):round(8):stroke("Tertiary", 1)
	box.FocusLost:connect(function() options.Callback(box.Text) end)

	local methods = {}
	function methods:Set(t) box.Text = t end
	return methods
end

function Library:color_picker(options)
	options = self:set_defaults({ Name = "Color Picker", Description = nil, Style = Library.ColorPickerStyles.Legacy, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local swatch = card:object("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 32),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	}):round(8)

	swatch.MouseButton1Click:connect(function()
		if Library._colorPickerExists then return end
		Library._colorPickerExists = true
		local selected = Color3.fromRGB(255, 0, 0)
		local hue, sat, val = 0, 1, 1

		local dark = self.core:object("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40
		}):round(16)
		local holder = dark:object("Frame", {
			Centered = true, Theme = {BackgroundColor3 = "Secondary"}, BackgroundTransparency = 0.05,
			Size = UDim2.fromOffset(240, 180)
		}):round(12):stroke("Tertiary", 1)
		holder.ZIndex = 41

		local picker = holder:object("TextButton", {
			Text = "", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0, 150, 0, 150),
			BackgroundTransparency = 1, ZIndex = 42
		}):round(8)
		local col = picker:object("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHSV(0, 1, 1), ZIndex = 43 }):round(8)
		local bright = picker:object("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 44 }):round(8)
		bright:object("UIGradient", {
			Color = ColorSequence.new(ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))),
			Transparency = NumberSequence.new(NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1))
		})
		local black = picker:object("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 45 }):round(8)
		local bg = black:object("UIGradient", {
			Color = ColorSequence.new(ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))),
			Transparency = NumberSequence.new(NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)), Rotation = -90
		})
		local knob = picker:object("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 50 }):round(100)

		local hueBar = holder:object("TextButton", {
			Text = "", Position = UDim2.new(0, 170, 0, 12), Size = UDim2.new(0, 20, 0, 150),
			BackgroundTransparency = 1, ZIndex = 42
		}):round(6)
		hueBar:object("UIGradient", {
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
			}
		})
		local hueKnob = hueBar:object("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 50 })

		local function update()
			selected = Color3.fromHSV(hue, sat, val)
			col.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			swatch.BackgroundColor3 = selected
		end
		update()

		local dp, dh = false, false
		picker.MouseButton1Down:Connect(function()
			dp = true
			while RunService.RenderStepped:wait() and dp do
				sat = math.clamp((Mouse.X - picker.AbsolutePosition.X) / picker.AbsoluteSize.X, 0, 1)
				val = 1 - math.clamp((Mouse.Y - picker.AbsolutePosition.Y) / picker.AbsoluteSize.Y, 0, 1)
				knob.Position = UDim2.fromScale(sat, 1 - val)
				update()
			end
		end)
		hueBar.MouseButton1Down:Connect(function()
			dh = true
			while RunService.RenderStepped:wait() and dh do
				hue = math.clamp((Mouse.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
				hueKnob.Position = UDim2.new(0.5, 0, hue, 0)
				update()
			end
		end)
		UserInputService.InputEnded:Connect(function(k)
			if k.UserInputType == Enum.UserInputType.MouseButton1 then dp = false; dh = false end
		end)

		local ok = holder:object("TextButton", {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(60, 26),
			Theme = {BackgroundColor3 = "Tertiary"}, Text = "PICK", TextSize = 12, Font = Enum.Font.GothamMedium, ZIndex = 46
		}):round(6)
		ok.TextColor3 = Library.CurrentTheme.Main
		local fadeOut
		fadeOut = function()
			dark:tween({BackgroundTransparency = 1, Length = 0.15}, function() dark.AbsoluteObject:Destroy() end)
			task.delay(0.3, function() Library._colorPickerExists = false end)
		end
		ok.MouseButton1Click:connect(function()
			options.Callback(selected)
			fadeOut()
		end)
		dark:tween({BackgroundTransparency = 0.45, Length = 0.15})
	end)

	return nil
end

function Library:keybind(options)
	options = self:set_defaults({ Name = "Keybind", Keybind = nil, Description = nil, Callback = function() end }, options)
	local card = self:_card(options.Name, options.Description, 56)
	local display = card:object("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(80, 32),
		Theme = {BackgroundColor3 = {"Secondary", -18}, TextColor3 = "Tertiary"},
		Text = (options.Keybind and tostring(options.Keybind.Name):upper()) or "?",
		TextSize = 13, Font = Enum.Font.GothamMedium
	}):round(8):stroke("Tertiary", 1)
	local listening = false
	display.MouseButton1Click:connect(function()
		if not listening then listening = true; display.Text = "..." end
	end)
	UserInputService.InputBegan:Connect(function(key, gp)
		if listening and not UserInputService:GetFocusedTextBox() then
			if key.UserInputType == Enum.UserInputType.Keyboard and key.KeyCode ~= Enum.KeyCode.Escape then
				options.Keybind = key.KeyCode
			end
			display.Text = (options.Keybind and tostring(options.Keybind.Name):upper()) or "?"
			listening = false
		elseif key.KeyCode == options.Keybind then
			options.Callback()
		end
	end)

	local methods = {}
	function methods:Set(k) options.Keybind = k; display.Text = (k and tostring(k.Name):upper()) or "?" end
	return methods
end

function Library:section(options)
	options = self:set_defaults({ Name = "Section" }, options)
	local section = self.container:object("Frame", {
		Theme = {BackgroundColor3 = {"Secondary", -6}},
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 0.25
	}):round(12):stroke("Tertiary", 1)
	local header = section:object("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamMedium,
		Text = options.Name,
		TextSize = 15,
		Theme = {TextColor3 = "Tertiary"},
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local inner = section:object("Frame", {
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(1, -24, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y
	})
	local layout = inner:object("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center })
	inner:object("UIPadding", { PaddingBottom = UDim.new(0, 10) })
	self:_resize_tab()
	return setmetatable({
		statusText = self.statusText,
		container = inner,
		sectionContainer = section,
		parentContainer = self.container,
		Theme = self.Theme,
		core = self.core,
		parentLayout = self.layout,
		layout = layout
	}, Library)
end

function Library:label(options)
	options = self:set_defaults({ Text = "Label", Description = "desc" }, options)
	local card = self:_card(options.Text, nil, 52)
	card:object("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.5, -12, 0, 22),
		Text = options.Description,
		TextSize = 14,
		Theme = {TextColor3 = "WeakText"},
		TextXAlignment = Enum.TextXAlignment.Right
	})
	local methods = {}
	function methods:SetText(t)
		local tl = card:FindFirstChildOfClass("TextLabel")
		if tl then tl.Text = t end
	end
	function methods:SetDescription(t)
		local lbls = card:GetChildren()
		for _, c in next, lbls do if c:IsA("TextLabel") and c ~= card:FindFirstChildOfClass("TextLabel") then c.Text = t end end
	end
	return methods
end

function Library:credit(options)
	options = self:set_defaults({ Name = "Creditor", Description = nil }, options)
	local card = self:_card(options.Name, options.Description, 48)
	if setclipboard then
		if options.Github then
			local b = card:object("ImageButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(26, 26),
				Theme = {BackgroundColor3 = {"Main", 12}}
			}):round(6):tooltip("copy github")
			b:object("ImageLabel", { Image = "rbxassetid://11965755499", Size = UDim2.fromOffset(16, 16), Centered = true, BackgroundTransparency = 1 }):round(100)
			b.MouseButton1Click:connect(function() setclipboard(options.Github) end)
		end
		if options.Discord then
			local b = card:object("ImageButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Color3.fromRGB(88, 101, 242)
			}):round(6):tooltip("copy discord")
			b.MouseButton1Click:connect(function() setclipboard(options.Discord) end)
		end
	end
	return nil
end

function Library:prompt(options)
	options = self:set_defaults({
		Followup = false, Title = "Prompt", Text = "?", Buttons = { ok = function() return true end }
	}, options)
	if Library._promptExists and not options.Followup then return end
	Library._promptExists = true

	local count = 0; for _ in next, options.Buttons do count += 1 end
	local dark = self.core:object("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60
	}):round(16)
	local box = dark:object("Frame", {
		Centered = true, Theme = {BackgroundColor3 = "Main"}, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(260, 130)
	}):round(12):stroke("Tertiary", 1)
	box:object("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 10),
		Font = Enum.Font.GothamMedium, Text = options.Title, Theme = {TextColor3 = "Tertiary"}, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center
	})
	box:object("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 50),
		Text = options.Text, Theme = {TextColor3 = "StrongText"}, TextSize = 13, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top
	})
	local holder = box:object("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 28), BackgroundTransparency = 1
	})
	holder:object("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local buttons = {}
	for text, cb in next, options.Buttons do
		local b = holder:object("TextButton", {
			Theme = {BackgroundColor3 = "Tertiary"}, Text = tostring(text):upper(), TextSize = 12, Font = Enum.Font.GothamMedium,
			Size = UDim2.new(1 / count, -8, 1, 0)
		}):round(6)
		b.TextColor3 = Library.CurrentTheme.Main
		table.insert(buttons, b)
		b.MouseEnter:connect(function() b:tween{BackgroundColor3 = Library:lighten(Library.CurrentTheme.Tertiary, 12)} end)
		b.MouseLeave:connect(function() b:tween{BackgroundColor3 = Library.CurrentTheme.Tertiary} end)
		b.MouseButton1Click:connect(function()
			dark:tween({BackgroundTransparency = 1, Length = 0.12}, function() dark.AbsoluteObject:Destroy(); task.delay(0.25, function() Library._promptExists = false end) end)
			cb()
		end)
	end
	dark:tween({BackgroundTransparency = 0.45, Length = 0.12})
end

function Library:_theme_selector()
	local card = self.container:object("Frame", {
		Theme = {BackgroundColor3 = "Secondary"}, Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 0.2
	}):round(12):stroke("Tertiary", 1)
	card:object("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamMedium, Text = "Theme", TextSize = 16, Theme = {TextColor3 = "StrongText"}, TextXAlignment = Enum.TextXAlignment.Left
	})
	local grid = card:object("Frame", {
		Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 44), BackgroundTransparency = 1
	})
	grid:object("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left })
	for name, th in next, Library.Themes do
		local sw = grid:object("TextButton", {
			Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1
		}):round(8):stroke("WeakText", 1)
		sw:object("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = th.Main }):round(8)
		sw.MouseButton1Click:connect(function()
			Library:change_theme(th); updateSettings("Theme", name)
		end)
	end
	self:_resize_tab()
end

function Library:notification(options)
	options = self:set_defaults({ Title = "Notification", Text = "", Duration = 3, Callback = function() end }, options)
	local noti = self.notifs:object("Frame", {
		BackgroundTransparency = 1, Theme = {BackgroundColor3 = "Main"}, Size = UDim2.new(0, 280, 0, 0)
	}):round(12):stroke("Tertiary", 1)
	noti:object("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
	noti:object("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://8628681683", Theme = {ImageColor3 = "Tertiary"}, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(18, 18) })
	noti:object("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -40, 0, 20),
		Font = Enum.Font.GothamMedium, Text = options.Title, Theme = {TextColor3 = "Tertiary"}, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
	})
	local txt = noti:object("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 24), Size = UDim2.new(1, 0, 0, 20),
		Text = options.Text, TextSize = 13, Theme = {TextColor3 = "StrongText"}, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top
	})
	noti:tween({BackgroundTransparency = 0.06, Size = UDim2.fromOffset(280, txt.TextBounds.Y + 44), Length = 0.2}, function()
		task.delay(options.Duration, function()
			noti:tween({BackgroundTransparency = 1, Size = UDim2.fromOffset(280, 0), Length = 0.2}, function()
				noti.AbsoluteObject:Destroy(); options.Callback()
			end)
		end)
	end)
end

function Library:cp(options) return Library.color_picker(self, options) end
function Library:colorpicker(options) return Library.color_picker(self, options) end

return setmetatable(Library, {
	__index = function(_, i)
		return rawget(Library, i:lower())
	end
})
