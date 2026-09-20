-- Mordox · cliente
-- Input direccional, cámara en primera/tercera persona (V), brazos y piernas de todos los caballeros por código,
-- armas dibujadas con la misma geometría que usa el servidor para pegar, HUD, killfeed y selección de arma.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("MordoxConfig"))
local Swing = require(ReplicatedStorage:WaitForChild("Swing"))
local Armor = require(ReplicatedStorage:WaitForChild("MordoxArmor"))
local remotes = ReplicatedStorage:WaitForChild("MordoxRemotes")
local CombatEvent = remotes:WaitForChild("Combat")
local FxEvent = remotes:WaitForChild("Fx")
local LookEvent = remotes:WaitForChild("Look")
local matchInfo = ReplicatedStorage:WaitForChild("MordoxMatch")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- modo desarrollador (F3) y tope de giro
local debugOn = false
local debugParts = {}
local turn = { yaw = nil, sens = 1, rate = 0 }

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function TS()
	return matchInfo:GetAttribute("TimeScale") or 1
end

-- Sonidos (biblioteca ProSoundEffects de Roblox: se pueden usar en cualquier juego)
local SOUNDS = {
	parry = { "rbxassetid://9119072660", "rbxassetid://9119072674" },
	block = { "rbxassetid://9116693083" },
	cut = { "rbxassetid://9117331172", "rbxassetid://9117330579" }, -- solo impactos, sin voces
	blunt = { "rbxassetid://9113565276" },
	kick = { "rbxassetid://9120487736" },
	clash = { "rbxassetid://9116764832" },
	death = { "rbxassetid://9113475819" },
	disarm = { "rbxassetid://9114007026" },
}

---------------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------------
local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold
local GOLD = Color3.fromRGB(230, 190, 110)
local WHITE = Color3.new(1, 1, 1)

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end

local function corner(r, parent)
	return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	local max = props.MaxSize or 28
	props.MaxSize = nil
	local l = new("TextLabel", props)
	new("UITextSizeConstraint", { MaxTextSize = max, Parent = l })
	return l
end

local gui = new("ScreenGui", { Name = "MordoxHUD", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })

-- barras de vida y stamina
local bars = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(0, 360, 0, 40),
	BackgroundTransparency = 1, Parent = gui })
local function bar(y, color)
	local back = new("Frame", { Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(25, 20, 20),
		BackgroundTransparency = 0.2, Parent = bars })
	corner(4, back)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = back })
	corner(4, fill)
	return fill
end
local healthFill = bar(0, Color3.fromRGB(190, 40, 35))
local staminaFill = bar(20, Color3.fromRGB(220, 185, 70))

-- mira con indicador de dirección de golpe
local cross = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 6, 0, 6),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, Parent = gui })
corner(3, cross)
local arrow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 4, 0, 16),
	BackgroundColor3 = GOLD, Parent = gui })
corner(2, arrow)
local opts = { fov = 90, volume = 0.8, sens = 1 } -- ajustes de la armería (M)
local buildWeapon, placeParts -- se definen más abajo, la armería los usa para la vista previa
local menuOpen, wasDead = false, false
local freeCam = { on = false, look = nil }

-- hacia dónde mira el caballero: la cámara, salvo en vista libre (ahí queda congelado)
local function aimLook()
	return freeCam.on and freeCam.look or camera.CFrame.LookVector
end

local toast = { text = "", untilT = 0 }
local stateText = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 30), Size = UDim2.new(0, 300, 0, 26),
	Text = "", TextColor3 = GOLD, MaxSize = 22, Parent = gui })

-- partida
local topBar = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0, 500, 0, 34),
	Text = "", MaxSize = 26, TextStrokeTransparency = 0.4, Parent = gui })
local banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0, 800, 0, 70),
	Text = "", TextColor3 = GOLD, MaxSize = 56, TextStrokeTransparency = 0.3, Visible = false, Parent = gui })

-- killfeed
local feed = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 360, 0, 200),
	BackgroundTransparency = 1, Parent = gui })
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = feed })

local function feedLine(text, color)
	local l = label({ Size = UDim2.new(1, 0, 0, 24), Text = text, Font = FONT2, TextColor3 = color or WHITE, MaxSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.3, Parent = feed })
	Debris:AddItem(l, 6)
end

-- tabla de puntaje (Tab)
local board = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0, 460, 0, 420),
	BackgroundColor3 = Color3.fromRGB(20, 16, 14), BackgroundTransparency = 0.1, Visible = false, Parent = gui })
corner(10, board)
label({ Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -32, 0, 32), Text = "TODOS CONTRA TODOS", TextColor3 = GOLD, Parent = board })
local boardList = new("Frame", { Position = UDim2.new(0, 16, 0, 50), Size = UDim2.new(1, -32, 1, -60), BackgroundTransparency = 1, Parent = board })
new("UIListLayout", { Padding = UDim.new(0, 4), Parent = boardList })

local function refreshBoard()
	for _, c in ipairs(boardList:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local s = p:FindFirstChild("leaderstats")
		table.insert(list, { p.DisplayName, s and s.Kills.Value or 0, s and s.Deaths.Value or 0, p == player })
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	for i, e in ipairs(list) do
		label({ Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Font = FONT2, MaxSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = e[4] and GOLD or WHITE, Text = string.format("%d.  %s     %d / %d", i, e[1], e[2], e[3]), Parent = boardList })
	end
end

-- armería (estilo Mordhau): vista 3D del arma y del caballero + piezas y ajustes
local function gearOf(char)
	local p = char and Players:GetPlayerFromCharacter(char)
	local gear = {}
	for key, default in pairs(Config.DefaultGear) do
		gear[key] = (p and p:GetAttribute("Gear" .. key)) or default
	end
	return gear
end

local function weaponStyleOf(char, weaponId)
	local p = char and Players:GetPlayerFromCharacter(char)
	local sty = {}
	for key, default in pairs(Config.DefaultWeaponStyle(weaponId)) do
		sty[key] = (p and p:GetAttribute("W" .. weaponId .. "_" .. key)) or default
	end
	return sty
end

local loadout = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 12, 11), BackgroundTransparency = 0.02,
	Visible = false, Parent = gui })
label({ Position = UDim2.new(0, 34, 0, 20), Size = UDim2.new(0, 500, 0, 40), Text = "ARMERÍA", TextColor3 = GOLD, MaxSize = 34,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = loadout })

-- vista 3D: arma a la izquierda, caballero al lado
local function viewport(pos, size, fieldOfView)
	local vp = new("ViewportFrame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(22, 19, 17),
		Ambient = Color3.fromRGB(150, 145, 140), LightColor = Color3.fromRGB(255, 245, 225), LightDirection = Vector3.new(-0.4, -0.7, -0.6),
		Parent = loadout })
	corner(10, vp)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = fieldOfView
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- arrastrar con el mouse gira el modelo; la rueda acerca y aleja
	local view = { yaw = 0, pitch = 0, zoom = 1, dist = 10, dragging = false, last = nil }
	vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			view.dragging, view.last = true, input.Position
		end
	end)
	vp.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			view.zoom = math.clamp(view.zoom - input.Position.Z * 0.12, 0.5, 2)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if view.dragging and input.UserInputType == Enum.UserInputType.MouseMovement and view.last then
			local d = input.Position - view.last
			view.last = input.Position
			view.yaw -= d.X * 0.01
			view.pitch = math.clamp(view.pitch + d.Y * 0.008, -1.1, 1.1)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			view.dragging, view.last = false, nil
		end
	end)
	return vp, world, cam, view
end

local swordVp, swordWorld, swordCam, swordView = viewport(UDim2.new(0, 34, 0, 80), UDim2.new(0, 740, 1, -160), 32)
local knightVp, knightWorld, knightCam, knightView = viewport(UDim2.new(0, 34, 0, 80), UDim2.new(0, 740, 1, -160), 26)
swordCam.CFrame = CFrame.lookAt(Vector3.new(0, 0, 7.5), Vector3.new(0, 0, 0))
knightCam.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, 11), Vector3.new(0, 0.2, 0))

local armorStats = label({ Position = UDim2.new(0, 34, 0, 58), Size = UDim2.new(0, 740, 0, 22), Font = FONT2,
	MaxSize = 17, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Visible = false, Parent = loadout })
local emptyView = label({ Position = UDim2.new(0, 34, 0, 80), Size = UDim2.new(0, 740, 1, -160), Font = FONT2, MaxSize = 20,
	TextColor3 = Color3.fromRGB(150, 140, 125), TextWrapped = true, Text = "", Parent = loadout })

local preview = { weapon = nil, key = "", knight = nil, knightKey = "" }

-- caballero de la armería: tu propio avatar en pose de descanso, con la armadura que elegís encima
local avatarPreview = { model = nil, key = "" }

-- pone el muñeco en la pose de reposo del esqueleto, parado en el origen
local function restPose(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new()
	local done = { [root] = true }
	for _ = 1, 8 do
		for _, m in ipairs(model:GetDescendants()) do
			if m:IsA("Motor6D") and m.Part0 and m.Part1 and done[m.Part0] and not done[m.Part1] then
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * m.C1:Inverse()
				done[m.Part1] = true
			end
		end
	end
	-- accesorios (pelo, sombreros) encima de su parte
	for _, acc in ipairs(model:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local att = handle and handle:FindFirstChildWhichIsA("Attachment")
			local target = att and model:FindFirstChild(att.Name, true)
			if target and target ~= att and target.Parent:IsA("BasePart") then
				handle.CFrame = target.WorldCFrame * att.CFrame:Inverse()
			end
		end
	end
end

local function buildAvatarPreview()
	if avatarPreview.model then
		return avatarPreview.model
	end
	local folder = ReplicatedStorage:FindFirstChild("MordoxPreviews")
	local src = folder and folder:FindFirstChild(tostring(player.UserId))
	if not src then
		return nil -- el servidor todavía no terminó de armar tu avatar
	end
	local model = src:Clone()
	restPose(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	model.Parent = knightWorld
	avatarPreview.model = model
	knightView.yaw = math.pi -- que te mire de frente al abrir
	-- el centro del cuerpo para girarlo y encuadrarlo
	local box, size = model:GetBoundingBox()
	avatarPreview.center = box.Position
	knightView.dist = math.clamp(size.Y, 5, 7) * 1.4 / (2 * math.tan(math.rad(13))) -- entero, con aire arriba y abajo
	return model
end

-- protección y peso de lo que tenés puesto, para mostrarlo en la armería
local function armorSummary(gear)
	local fx = Armor.effects(gear)
	local function pct(mul)
		return math.floor((1 - mul) * 100 + 0.5)
	end
	return string.format("Protección · cabeza %d%% · torso %d%% · piernas %d%%      Velocidad %d%%",
		pct(fx.head), pct(fx.torso), pct(fx.legs), math.floor(fx.speed * 100 + 0.5))
end

local function refreshPreview(gear, weapon, sty)
	local parts = {}
	for k, v in pairs(sty) do
		table.insert(parts, k .. "=" .. v)
	end
	table.sort(parts)
	local key = weapon.Id .. "|" .. table.concat(parts, "|")
	if preview.key ~= key then
		preview.key = key
		if preview.weapon then
			preview.weapon.model:Destroy()
		end
		preview.weapon = buildWeapon(weapon, sty, swordWorld)
		-- la cámara no se ajusta al arma: así se nota que el mandoble es más largo que el espadón
		local longest = 0
		for _, w in ipairs(Config.Weapons) do
			longest = math.max(longest, w.Length + w.Grip + 0.9)
		end
		swordView.dist = longest / (2 * math.tan(math.rad(16)))
		swordView.offset = (weapon.Grip + 0.25 - weapon.Length) / 2 -- centro del arma en el eje de la hoja
	end
	local kkey = table.concat({ gear.Head, gear.Chest, gear.Legs, gear.Armor, gear.Tabard }, "|")
	local model = buildAvatarPreview()
	if model and avatarPreview.key ~= kkey then
		avatarPreview.key = kkey
		model:PivotTo(CFrame.new()) -- la armadura se arma con el muñeco derecho y después gira con él
		Armor.apply(model, gear, true)
	end
end

-- columna derecha: piezas del arma, caballero y ajustes
local tabs = { current = "arma", rows = {}, buttons = {} }
local tabBar = new("Frame", { Position = UDim2.new(0, 794, 0, 26), Size = UDim2.new(1, -828, 0, 44), BackgroundTransparency = 1, Parent = loadout })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = tabBar })
for i, tab in ipairs({ { Id = "arma", Name = "ARMA" }, { Id = "equipo", Name = "EQUIPO" }, { Id = "ajustes", Name = "AJUSTES" } }) do
	local b = new("TextButton", { Size = UDim2.new(0, 150, 1, 0), LayoutOrder = i, Text = "", AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(45, 37, 30), Parent = tabBar })
	corner(6, b)
	label({ Size = UDim2.fromScale(1, 1), Text = tab.Name, MaxSize = 18, Parent = b })
	b.MouseButton1Click:Connect(function()
		tabs.current = tab.Id
	end)
	tabs.buttons[tab.Id] = b
end

local menuList = new("ScrollingFrame", { Position = UDim2.new(0, 794, 0, 80), Size = UDim2.new(1, -828, 1, -160), BackgroundTransparency = 1,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = loadout })
new("UIListLayout", { Padding = UDim.new(0, 8), Parent = menuList })

local styleButtons, gearButtons, weaponRows = {}, {}, {}

local function menuRow(order, title, tab)
	local row = new("Frame", { Size = UDim2.new(1, -10, 0, 64), LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(30, 25, 21),
		BackgroundTransparency = 0.2, Parent = menuList })
	corner(6, row)
	label({ Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -20, 0, 20), Text = title, MaxSize = 16, Font = FONT2,
		TextColor3 = Color3.fromRGB(215, 200, 175), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local holder = new("Frame", { Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1, Parent = row })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = holder })
	table.insert(tabs.rows, { row = row, tab = tab })
	return holder
end

-- primera pantalla de la pestaña ARMA: la lista de armas (por ahora solo el espadón)
local weaponButtons = {}
local weaponList = new("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0,
	BackgroundTransparency = 1, Parent = menuList })
new("UIListLayout", { Padding = UDim.new(0, 8), Parent = weaponList })
for i, w in ipairs(Config.Weapons) do
	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 86), LayoutOrder = i, Text = "", AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(45, 37, 30), Parent = weaponList })
	corner(6, b)
	label({ Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 28), Text = w.Name, MaxSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
	label({ Position = UDim2.new(0, 14, 0, 40), Size = UDim2.new(1, -28, 0, 38), Font = FONT2, MaxSize = 15,
		TextColor3 = Color3.fromRGB(200, 190, 175), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = string.format("Dos manos · daño %d al tajo, %d a la estocada\nalcance %.1f · carga %.2f s · tocá para forjarla",
			w.Slash.Damage, w.Stab.Damage, w.Length, w.Slash.Windup), Parent = b })
	b.MouseButton1Click:Connect(function()
		CombatEvent:FireServer("loadout", w.Id)
		tabs.weapon = w.Id
		buildWeaponRows(w.Id)
	end)
	weaponButtons[w.Id] = b
end

local backButton = new("TextButton", { Size = UDim2.new(0, 220, 0, 34), LayoutOrder = 0, Text = "", AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(45, 37, 30), Parent = menuList })
corner(6, backButton)
label({ Size = UDim2.fromScale(1, 1), Text = "← Volver a las armas", MaxSize = 16, Font = FONT2, Parent = backButton })
backButton.MouseButton1Click:Connect(function()
	tabs.weapon = nil
end)

local function optionButtons(holder, cat, onPick)
	local map = {}
	for j, opt in ipairs(cat.Options) do
		local b = new("TextButton", { Size = UDim2.new(0, opt.Color and 44 or 118, 1, 0), LayoutOrder = j, Text = "", AutoButtonColor = true,
			BackgroundColor3 = opt.Color or Color3.fromRGB(45, 37, 30), Parent = holder })
		corner(5, b)
		if not opt.Color then
			label({ Size = UDim2.fromScale(1, 1), Text = opt.Name, MaxSize = 14, Font = FONT2, TextWrapped = true, Parent = b })
		end
		b.MouseButton1Click:Connect(function()
			onPick(opt.Id)
		end)
		map[opt.Id] = b
	end
	return map
end

for i, cat in ipairs(Config.GearCustom) do
	local holder = menuRow(100 + i, cat.Name, "equipo")
	gearButtons[cat.Key] = optionButtons(holder, cat, function(id)
		CombatEvent:FireServer("gear", cat.Key, id)
	end)
end

-- las piezas del arma se arman de nuevo cada vez que entrás a forjar otra arma
local builtRowsFor
local function buildWeaponRows(weaponId)
	builtRowsFor = weaponId
	for _, row in ipairs(weaponRows) do
		row:Destroy()
	end
	table.clear(weaponRows)
	table.clear(styleButtons)
	for i, cat in ipairs(Config.WeaponCustom[weaponId] or {}) do
		local holder = menuRow(i, cat.Name, "arma")
		table.insert(weaponRows, holder.Parent)
		styleButtons[cat.Key] = optionButtons(holder, cat, function(id)
			CombatEvent:FireServer("style", weaponId .. ":" .. cat.Key, id)
		end)
	end
end

for i, cfg in ipairs({
	{ Key = "fov", Name = "Campo de visión", Step = 5, Min = 60, Max = 120, Fmt = "%d" },
	{ Key = "volume", Name = "Volumen", Step = 0.1, Min = 0, Max = 1, Fmt = "%d%%", Scale = 100 },
	{ Key = "sens", Name = "Sensibilidad del mouse", Step = 0.1, Min = 0.2, Max = 2, Fmt = "%.1f" },
}) do
	local holder = menuRow(200 + i, cfg.Name, "ajustes")
	local value
	local function show()
		value.Text = string.format(cfg.Fmt, opts[cfg.Key] * (cfg.Scale or 1))
	end
	for _, dir in ipairs({ -1, 1 }) do
		local b = new("TextButton", { Size = UDim2.new(0, 44, 1, 0), LayoutOrder = dir < 0 and 1 or 3, Text = dir < 0 and "−" or "+",
			Font = FONT, TextSize = 22, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(45, 37, 30), Parent = holder })
		corner(5, b)
		b.MouseButton1Click:Connect(function()
			opts[cfg.Key] = math.clamp(math.floor((opts[cfg.Key] + dir * cfg.Step) * 100 + 0.5) / 100, cfg.Min, cfg.Max)
			show()
		end)
	end
	value = label({ Size = UDim2.new(0, 90, 1, 0), LayoutOrder = 2, Text = "", MaxSize = 17, Parent = holder })
	show()
end

-- pie: nombre del arma y botón para salir al campo
local weaponFoot = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 34, 1, -24), Size = UDim2.new(0, 500, 0, 30), Font = FONT2,
	MaxSize = 18, TextColor3 = Color3.fromRGB(205, 195, 180), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = loadout })
local spawnButton = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -34, 1, -20), Size = UDim2.new(0, 320, 0, 52),
	Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(120, 80, 30), Parent = loadout })
corner(8, spawnButton)
local spawnLabel = label({ Size = UDim2.fromScale(1, 1), Text = "SALIR AL CAMPO", MaxSize = 24, Parent = spawnButton })
spawnButton.MouseButton1Click:Connect(function()
	CombatEvent:FireServer("spawn")
	CombatEvent:FireServer("armory", false)
	menuOpen = false
end)

local deathText = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0, 600, 0, 40),
	Text = "", MaxSize = 30, TextStrokeTransparency = 0.3, Visible = false, Parent = gui })

local help = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(0, 520, 0, 90), Font = FONT2,
	MaxSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
	TextColor3 = Color3.fromRGB(220, 210, 195), TextStrokeTransparency = 0.4, Parent = gui,
	Text = "Clic izq: golpe (mové el mouse para elegir la dirección) · Rueda arriba: estocada · Rueda abajo: golpe de arriba\nClic der: parry (con escudo: mantener) · Q: fintar · F: patada · G: soltar o levantar el arma · Shift: correr · V: cámara · Alt (mantener): vista libre · [ ]: FOV · Tab: tabla · F3: modo desarrollador · F4: cámara lenta · M: forja y ajustes · H: ocultar ayuda" })
local debugText = label({ Position = UDim2.new(0, 14, 0, 60), Size = UDim2.new(0, 420, 0, 190), Font = Enum.Font.Code, MaxSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(120, 255, 140),
	TextStrokeTransparency = 0.3, Text = "", Visible = false, Parent = gui })

---------------------------------------------------------------------------
-- Armas (solo visuales, locales)
---------------------------------------------------------------------------
local weaponFolder = new("Folder", { Name = "MordoxWeapons", Parent = workspace })

local function weaponPart(model, size, color, offset, material, shape)
	local p = new("Part", { Size = size, Color = color, Material = material or Enum.Material.Metal, Anchored = true, CanCollide = false,
		CanQuery = false, CanTouch = false, CastShadow = true, Shape = shape or Enum.PartType.Block, Parent = model })
	return { p, offset }
end

-- piezas en el marco de la empuñadura: origen en la mano derecha, -Z hacia la punta
-- El espadón se arma con las piezas elegidas en la forja (hoja, guarda, empuñadura y pomo).
function buildWeapon(w, sty, parent)
	local model = new("Model", { Name = w.Id, Parent = parent or weaponFolder })
	local parts = {}
	local blade = Config.WeaponOption(w.Id, "Blade", sty.Blade)
	local guard = Config.WeaponOption(w.Id, "Guard", sty.Guard)
	local grip = Config.WeaponOption(w.Id, "Grip", sty.Grip)
	local pommel = Config.WeaponOption(w.Id, "Pommel", sty.Pommel)
	local metal = Config.WeaponOption(w.Id, "Metal", sty.Metal)
	local ricasso = Config.WeaponOption(w.Id, "Ricasso", sty.Ricasso)
	local steel, dark = metal.Color, metal.Dark
	local L, G = w.Length, w.Grip
	local function add(size, color, pos, material, shape, rot)
		table.insert(parts, weaponPart(model, size, color, CFrame.new(pos) * (rot or CFrame.identity), material, shape))
	end

	-- hoja: cuerpo, punta y (según el tipo) canal central u ondas
	local bladeLen = L - 0.35
	local bodyLen = bladeLen - 0.7
	if blade.Wave then
		-- flamígera: tramos alternados que dan la silueta ondulada
		local segs = 5
		local segLen = bodyLen / segs
		for i = 0, segs - 1 do
			local z = -0.35 - segLen * (i + 0.5)
			local side = (i % 2 == 0) and 1 or -1
			add(Vector3.new(blade.Thick, blade.Width, segLen * 1.35), steel, Vector3.new(0, side * blade.Width * 0.1, z), nil, nil,
				CFrame.Angles(side * 0.09, 0, 0))
		end
	else
		add(Vector3.new(blade.Thick, blade.Width, bodyLen), steel, Vector3.new(0, 0, -0.35 - bodyLen / 2))
	end
	add(Vector3.new(blade.Thick * 0.9, blade.Width * blade.Tip, 0.7), steel, Vector3.new(0, 0, -0.35 - bodyLen - 0.35))
	if ricasso then
		-- ricasso: el tramo sin filo arriba de la guarda, para agarrar la hoja con la mano
		if ricasso.Wrap then
			add(Vector3.new(blade.Thick * 1.15, blade.Width * 0.85, 1.1), ricasso.Wrap, Vector3.new(0, 0, -1),
				Enum.Material[ricasso.Material] or Enum.Material.Leather)
		end
		if ricasso.Lugs then
			for _, side in ipairs({ -1, 1 }) do
				add(Vector3.new(0.11, 0.55, 0.15), dark, Vector3.new(0, side * blade.Width * 0.75, -1.5), nil, nil, CFrame.Angles(side * 0.6, 0, 0))
			end
		end
	end
	if blade.Fuller then
		add(Vector3.new(blade.Thick + 0.02, blade.Width * 0.3, bodyLen * 0.8), dark, Vector3.new(0, 0, -0.35 - bodyLen / 2))
	end

	-- guarda
	-- la guarda se abre hacia los filos (mismo eje que el ancho de la hoja), no hacia las caras planas
	local span = guard.Span
	if guard.Style == "recta" then
		add(Vector3.new(0.12, span, 0.13), dark, Vector3.new(0, 0, -0.28))
	elseif guard.Style == "curva" then
		for _, side in ipairs({ -1, 1 }) do
			add(Vector3.new(0.12, span * 0.55, 0.13), dark, Vector3.new(0, side * span * 0.26, -0.3), nil, nil, CFrame.Angles(side * 0.35, 0, 0))
		end
		add(Vector3.new(0.14, 0.2, 0.15), dark, Vector3.new(0, 0, -0.28))
	elseif guard.Style == "anillos" then
		add(Vector3.new(0.12, span, 0.13), dark, Vector3.new(0, 0, -0.28))
		for _, side in ipairs({ -1, 1 }) do
			add(Vector3.new(0.08, 0.32, 0.32), dark, Vector3.new(0, side * span * 0.3, -0.1), nil, Enum.PartType.Cylinder)
		end
	else -- ese: barra recta y las dos puntas dobladas en sentidos opuestos (una hacia la hoja, otra hacia el pomo)
		local barHalf = span * 0.33
		local tipHalf = span * 0.19
		local ang = 0.95
		add(Vector3.new(0.12, barHalf * 2, 0.13), dark, Vector3.new(0, 0, -0.28))
		for _, side in ipairs({ -1, 1 }) do
			local dy = side * (barHalf + math.cos(ang) * tipHalf)
			local dz = side * math.sin(ang) * tipHalf
			add(Vector3.new(0.12, tipHalf * 2, 0.13), dark, Vector3.new(0, dy, -0.28 + dz), nil, nil, CFrame.Angles(ang, 0, 0))
		end
	end

	-- empuñadura
	local gripMat = Enum.Material[grip.Material] or Enum.Material.Leather
	add(Vector3.new(0.15, 0.15, G + 0.3), grip.Color, Vector3.new(0, 0, (G + 0.3) / 2 - 0.25), gripMat)
	if grip.Rings then
		for i = 1, 4 do
			add(Vector3.new(0.17, 0.17, 0.05), grip.Color, Vector3.new(0, 0, -0.1 + i * (G / 4.5)), gripMat)
		end
	end

	-- pomo
	local pz = G + 0.1
	if pommel.Shape == "bola" then
		add(Vector3.new(0.26, 0.26, 0.26), dark, Vector3.new(0, 0, pz), nil, Enum.PartType.Ball)
	elseif pommel.Shape == "disco" then
		add(Vector3.new(0.12, 0.34, 0.34), dark, Vector3.new(0, 0, pz), nil, Enum.PartType.Cylinder)
	elseif pommel.Shape == "pera" then
		add(Vector3.new(0.22, 0.22, 0.22), dark, Vector3.new(0, 0, pz - 0.06), nil, Enum.PartType.Ball)
		add(Vector3.new(0.3, 0.3, 0.3), dark, Vector3.new(0, 0, pz + 0.1), nil, Enum.PartType.Ball)
	else -- escudete
		add(Vector3.new(0.3, 0.3, 0.16), steel, Vector3.new(0, 0, pz))
		add(Vector3.new(0.16, 0.16, 0.2), dark, Vector3.new(0, 0, pz + 0.08))
	end
	return { model = model, parts = parts, shield = nil }
end

function placeParts(entries, cf)
	for _, e in ipairs(entries) do
		e[1].CFrame = cf * e[2]
	end
end

local function destroyWeapon(wv)
	if wv then
		wv.model:Destroy()
		if wv.shield then
			wv.shield.model:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Estado local (predicción) y lectura del estado replicado
---------------------------------------------------------------------------
local predicted = nil -- { State, Kind, Angle, Phase, PhaseStart, PhaseDur, at }

local function readState(char)
	local st = {
		State = char:GetAttribute("St") or "idle",
		Kind = char:GetAttribute("Kind") or "",
		Angle = char:GetAttribute("Angle") or 0,
		Phase = char:GetAttribute("Phase") or "",
		PhaseStart = char:GetAttribute("PhaseStart") or 0,
		PhaseDur = char:GetAttribute("PhaseDur") or 0,
	}
	if char == player.Character and predicted then
		-- la predicción vale hasta que el servidor confirma (o 0.3 s)
		if st.PhaseStart >= predicted.PhaseStart - 0.05 or os.clock() - predicted.at > 0.3 then
			predicted = nil
		else
			st = predicted
		end
	end
	return st
end

local function poseState(st, weapon, t)
	local s = { State = st.State, Kind = st.Kind, Angle = st.Angle, Phase = st.Phase, T = 0 }
	if st.PhaseDur > 0 then
		s.T = math.clamp((t - st.PhaseStart) / st.PhaseDur, 0, 1)
	end
	-- mientras el servidor no mande la siguiente fase, avanzar localmente para que no se congele
	if s.State == "attack" and s.T >= 1 then
		local data = s.Kind == "stab" and weapon.Stab or weapon.Slash
		local over = t - st.PhaseStart - st.PhaseDur
		if s.Phase == "windup" then
			s.Phase, s.T = "release", math.clamp(over / (data.Release * TS()), 0, 1)
		elseif s.Phase == "release" then
			s.Phase, s.T = "recovery", math.clamp(over / (data.Recovery * TS()), 0, 1)
		end
	end
	return s
end

---------------------------------------------------------------------------
-- Animación de caballeros (brazos por IK hacia la empuñadura, piernas al caminar)
---------------------------------------------------------------------------
local knights = {} -- [character] = datos (claves fuertes: al desaparecer el personaje se borra su arma)

local function solveIK(root, target, a, b, pole)
	local d = target - root
	local dist = d.Magnitude
	local dir = dist > 1e-4 and d / dist or Vector3.new(0, -1, 0)
	dist = math.clamp(dist, 0.1, a + b - 0.01)
	local cosA = math.clamp((a * a + dist * dist - b * b) / (2 * a * dist), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local p = pole - dir * pole:Dot(dir)
	if p.Magnitude < 1e-3 then
		p = Vector3.yAxis
	end
	p = p.Unit
	return root + dir * (a * cosA) + p * (a * sinA), root + dir * dist
end

local function turnTo(fromDir, toDir)
	local axis = fromDir:Cross(toDir)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(fromDir:Dot(toDir), -1, 1)))
end

local function limbInfo(char, side, upperName, lowerName, endName, rootJoint, midJoint, endJoint)
	local upper, lower, tip = char:FindFirstChild(side .. upperName), char:FindFirstChild(side .. lowerName), char:FindFirstChild(side .. endName)
	local j1 = upper and upper:FindFirstChild(side .. rootJoint)
	local j2 = lower and lower:FindFirstChild(side .. midJoint)
	local j3 = tip and tip:FindFirstChild(side .. endJoint)
	if not (j1 and j2 and j3) then
		return nil
	end
	return {
		j1 = j1, j2 = j2,
		len1 = (j2.C0.Position - j1.C1.Position).Magnitude,
		len2 = (j3.C0.Position - j2.C1.Position).Magnitude + tip.Size.Y * 0.35,
		dir1 = (j1.C1:Inverse() * j2.C0.Position).Unit, -- hacia el codo/rodilla en el marco de la articulación
		dir2 = (j2.C1:Inverse() * j3.C0.Position).Unit,
	}
end

local function aimLimb(info, target, pole)
	local parent0 = info.j1.Part0
	local rest1 = parent0.CFrame * info.j1.C0
	local elbow, hand = solveIK(rest1.Position, target, info.len1, info.len2, pole)
	local cur1 = rest1:VectorToWorldSpace(info.dir1)
	local rot1 = turnTo(cur1, (elbow - rest1.Position).Unit)
	local t1 = rest1.Rotation:Inverse() * rot1 * rest1.Rotation
	info.j1.Transform = t1
	local upperCF = rest1 * t1 * info.j1.C1:Inverse()
	local rest2 = upperCF * info.j2.C0
	local cur2 = rest2:VectorToWorldSpace(info.dir2)
	local rot2 = turnTo(cur2, (hand - rest2.Position).Unit)
	info.j2.Transform = rest2.Rotation:Inverse() * rot2 * rest2.Rotation
end

local function knightData(char)
	local k = knights[char]
	if k then
		return k
	end
	if not char:FindFirstChild("UpperTorso") then
		return nil
	end
	k = {
		rArm = limbInfo(char, "Right", "UpperArm", "LowerArm", "Hand", "Shoulder", "Elbow", "Wrist"),
		lArm = limbInfo(char, "Left", "UpperArm", "LowerArm", "Hand", "Shoulder", "Elbow", "Wrist"),
		rLeg = limbInfo(char, "Right", "UpperLeg", "LowerLeg", "Foot", "Hip", "Knee", "Ankle"),
		lLeg = limbInfo(char, "Left", "UpperLeg", "LowerLeg", "Foot", "Hip", "Knee", "Ankle"),
		walk = 0,
	}
	if not (k.rArm and k.lArm and k.rLeg and k.lLeg) then
		return nil -- el cuerpo todavía está llegando (articulaciones sin replicar): se vuelve a intentar el próximo cuadro
	end
	knights[char] = k
	return k
end

-- suaviza la pose del arma en el espacio del cuerpo: una finta o un cambio brusco de estado vuelve a la guardia sin salto.
-- Durante el impacto no se suaviza, para que lo que se ve sea exactamente lo que pega.
local function smoothWeapon(sm, body, base, dir, st, dt, length, edge)
	local localBase, localDir = body:PointToObjectSpace(base), body:VectorToObjectSpace(dir)
	local localEdge = body:VectorToObjectSpace(edge or body.UpVector)
	if not sm.base or (st.State == "attack" and st.Phase == "release") then
		sm.base, sm.dir, sm.edge = localBase, localDir, localEdge
	else
		local k = 1 - math.exp(-dt * 12)
		local morphKey = st.State == "attack" and st.Phase == "windup" and (st.Kind .. ":" .. math.floor(st.Angle)) or nil
		if morphKey and sm.morphKey and morphKey ~= sm.morphKey then
			-- morph: la hoja se recoge hacia el pecho y sale hacia la carga del golpe nuevo
			local tt = math.clamp(st.T or 0, 0, 1)
			sm.morph = { t = 0, dur = math.clamp((1 - tt) * 0.55, 0.12, 0.3), base = sm.base, dir = sm.dir, edge = sm.edge or localEdge }
		end
		sm.morphKey = morphKey
		local mo = sm.morph
		if mo and morphKey then
			mo.t += dt
			local e = math.clamp(mo.t / mo.dur, 0, 1)
			local ease = e * e * (3 - 2 * e)
			local arc = math.sin(math.pi * e)
			local chest = Vector3.new(0, 1.1, -0.6)
			sm.base = mo.base:Lerp(localBase, ease):Lerp(chest, arc * 0.45)
			local d = mo.dir:Lerp(localDir, ease) + Vector3.new(0, arc * 0.6, 0)
			sm.dir = d.Magnitude > 1e-3 and d.Unit or localDir
			local ed = mo.edge:Lerp(localEdge, ease)
			sm.edge = ed.Magnitude > 1e-3 and ed.Unit or localEdge
			if e >= 1 then
				sm.morph = nil
			end
			local b, dd = body:PointToWorldSpace(sm.base), body:VectorToWorldSpace(sm.dir)
			return b, b + dd * length, dd, body:VectorToWorldSpace(sm.edge)
		elseif st.State == "attack" and st.Phase == "windup" then
			-- combos: la carga nace desde donde terminó el golpe anterior y llega exacta al impacto
			local tt = math.clamp(st.T or 0, 0, 1)
			k = k + (1 - k) * tt * tt * tt
		end
		sm.base = sm.base:Lerp(localBase, k)
		local d = sm.dir:Lerp(localDir, k)
		sm.dir = d.Magnitude > 1e-3 and d.Unit or localDir
		local e = (sm.edge or localEdge):Lerp(localEdge, k)
		sm.edge = e.Magnitude > 1e-3 and e.Unit or localEdge
	end
	local b, d = body:PointToWorldSpace(sm.base), body:VectorToWorldSpace(sm.dir)
	return b, b + d * length, d, body:VectorToWorldSpace(sm.edge)
end

local function animateKnight(char, t, dt)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local k = hrp and hum and knightData(char)
	if not k or hum.Health <= 0 or not (k.rArm and k.lArm) then
		return
	end
	if char:GetAttribute("Unarmed") then
		destroyWeapon(k.weapon)
		k.weapon, k.weaponId = nil, nil
		return
	end
	local weapon = Config.Weapon(char:GetAttribute("Weapon") or "espadon")
	local sty = weaponStyleOf(char, weapon.Id)
	local parts = { weapon.Id }
	for k2, v in pairs(sty) do
		table.insert(parts, k2 .. "=" .. v)
	end
	table.sort(parts)
	local key = table.concat(parts, "|")
	if not k.weapon or k.weaponId ~= key then
		destroyWeapon(k.weapon)
		k.weapon = buildWeapon(weapon, sty)
		k.weaponId = key
	end
	local st = poseState(readState(char), weapon, t)
	local isLocal = char == player.Character
	local pitch = isLocal and k.localPitch or (char:GetAttribute("Pitch") or 0)
	local body = hrp.CFrame
	if isLocal then
		local look = aimLook()
		body = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	end
	local base, tip, dir, edge = Swing.WorldPose(body, pitch, weapon, st)
	k.smAnim = k.smAnim or {}
	base, tip, dir, edge = smoothWeapon(k.smAnim, body, base, dir, st, dt, weapon.Length, edge)
	k.body, k.pitch, k.st, k.weaponDef = body, pitch, st, weapon

	-- brazo derecho a la empuñadura; el izquierdo más atrás en el mango (dos manos) o con el escudo
	-- el codo apunta hacia afuera y abajo; si la mano cruza al otro lado, hacia adelante para no meterse en el pecho
	local function elbowPole(hand, side)
		local localHand = body:PointToObjectSpace(hand)
		local crossed = math.clamp(-side * localHand.X / 1.2, 0, 1)
		return body:VectorToWorldSpace(Vector3.new(side * (1 - crossed), -1, 0.3 - crossed * 1.3))
	end
	aimLimb(k.rArm, base, elbowPole(base, 1))
	local gripCF = CFrame.lookAt(base, base + dir, edge) -- el ancho de la hoja sigue al filo: corta con el filo, no de plano
	if weapon.Kind == "twohand" then
		-- la izquierda agarra el mango más abajo, a la medida de la empuñadura de cada arma
		-- (sin apartarla del cuerpo: si no, la mano se despega del mango)
		local leftHand = base - dir * (weapon.Grip * 0.45 + 0.1)
		aimLimb(k.lArm, leftHand, elbowPole(leftHand, -1))
	else
		local blocking = st.State == "block"
		local shieldPos = body:PointToWorldSpace(blocking and Vector3.new(-0.15, 1.2, -1.35) or Vector3.new(-0.9, 0.35, -0.8))
		aimLimb(k.lArm, shieldPos, body:VectorToWorldSpace(Vector3.new(-1, -1, 0.4)))
		if k.weapon.shield then
			local sDir = blocking and body.LookVector or (body.LookVector - body.RightVector * 0.5).Unit
			placeParts(k.weapon.shield.parts, CFrame.lookAt(shieldPos, shieldPos + sDir, body.UpVector))
		end
	end
	placeParts(k.weapon.parts, gripCF)

	-- piernas: paso según la velocidad horizontal; patada levanta la derecha
	-- flinch: el torso se sacude hacia atrás al recibir un golpe
	if k.flinchAt then
		local ft = (os.clock() - k.flinchAt) / 0.35
		local waist = char:FindFirstChild("UpperTorso") and char.UpperTorso:FindFirstChild("Waist")
		if waist then
			if ft < 1 then
				local amt = math.sin(math.min(ft * 3, 1) * math.pi / 2) * (1 - ft)
				waist.Transform = CFrame.Angles(math.rad(22 * amt), math.rad(12 * amt), 0)
			else
				waist.Transform = CFrame.identity
				k.flinchAt = nil
			end
		end
	end
	if k.rLeg and k.lLeg then
		local vel = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = vel.Magnitude
		k.walk += dt * speed * 0.55
		local swing = math.clamp(speed / 16, 0, 1)
		local forward = body.LookVector
		local localVel = speed > 0.1 and body:VectorToObjectSpace(vel).Unit or Vector3.zero
		for i, leg in ipairs({ k.rLeg, k.lLeg }) do
			local phase = k.walk + (i == 1 and 0 or math.pi)
			local hipPos = (leg.j1.Part0.CFrame * leg.j1.C0).Position
			local step = body:VectorToWorldSpace(localVel * math.sin(phase) * 1.1 * swing)
			local lift = math.max(0, math.cos(phase)) * 0.55 * swing
			local foot = hipPos - body.UpVector * (leg.len1 + leg.len2 - 0.25) + step + body.UpVector * lift
				+ body.RightVector * (i == 1 and 0.15 or -0.15)
			if st.State == "kick" and i == 1 then
				local kk = st.Phase == "windup" and math.sin(math.clamp((t - (char:GetAttribute("PhaseStart") or t)) / Config.Combat.KickWindup, 0, 1) * math.pi / 2) or 0.4
				foot = hipPos + forward * (leg.len1 + leg.len2) * 0.9 * kk + body.UpVector * (-0.9 + kk * 0.7)
			end
			aimLimb(leg, foot, forward)
		end
	end
	return st
end

---------------------------------------------------------------------------
-- Cámara: primera persona / tercera persona (V)
---------------------------------------------------------------------------
local firstPerson = true
local function applyCameraMode()
	if freeCam.on then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 4
		player.CameraMaxZoomDistance = 30
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = Vector3.new(0, 0.5, 0) -- la cámara orbita el centro del cuerpo
			hum.AutoRotate = false
		end
		return
	end
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 9
		player.CameraMaxZoomDistance = 9
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = firstPerson and Vector3.new(0, 0.2, 0.1) or Vector3.new(2, 0.6, 0)
		hum.AutoRotate = firstPerson
	end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local fovToast = 0 -- aviso al cambiar el campo de visión con [ y ]
local mouseDir = Vector2.new(0.6, -0.4) -- dirección acumulada del mouse (x derecha, y arriba)
local lastPitchSent = 0

local function currentAngle()
	if mouseDir.Magnitude < 0.15 then
		return 45
	end
	return math.deg(math.atan2(mouseDir.X, mouseDir.Y))
end

local function predictAttack(kind, angle)
	local char = player.Character
	if not char then
		return
	end
	local st = char:GetAttribute("St")
	local weapon = Config.Weapon(char:GetAttribute("Weapon") or "espadon")
	local phase = char:GetAttribute("Phase")
	local comboable = st == "attack" and phase == "recovery" and char:GetAttribute("CanCombo") == true
		and (char:GetAttribute("Stamina") or 0) >= Config.Stamina.ComboMin
	local shieldRiposte = st == "block" and serverNow() <= (char:GetAttribute("RiposteUntil") or 0)
	if st == "idle" or st == "riposte" or comboable or shieldRiposte then
		local data = kind == "stab" and weapon.Stab or weapon.Slash
		local scale = (st == "riposte" or shieldRiposte) and Config.Combat.RiposteWindupScale or (comboable and Config.Combat.ComboWindupScale or 1)
		predicted = { State = "attack", Kind = kind, Angle = angle, Phase = "windup", PhaseStart = serverNow(), PhaseDur = data.Windup * scale * TS(), at = os.clock() }
	end
end

local function attack(kind, angle)
	if loadout.Visible or freeCam.on then
		return -- con la armería abierta no se pelea
	end
	predictAttack(kind, angle)
	CombatEvent:FireServer("attack", kind, angle)
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = Vector2.new(input.Delta.X, -input.Delta.Y)
		if d.Magnitude > 0.5 then
			mouseDir = mouseDir * 0.75 + d.Unit * 0.25
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not loadout.Visible and not freeCam.on then
		if input.Position.Z > 0 then
			attack("stab", 0)
		else
			attack("slash", 0)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not loadout.Visible then
			attack("slash", currentAngle())
		end
		return
	end
	if processed then
		return
	end
	if loadout.Visible and input.KeyCode ~= Enum.KeyCode.M and input.KeyCode ~= Enum.KeyCode.H and input.KeyCode ~= Enum.KeyCode.Tab then
		return -- con la forja abierta el teclado no pelea
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		CombatEvent:FireServer("parry")
	elseif input.KeyCode == Enum.KeyCode.Q then
		predicted = nil
		CombatEvent:FireServer("feint")
	elseif input.KeyCode == Enum.KeyCode.F then
		CombatEvent:FireServer("kick")
	elseif input.KeyCode == Enum.KeyCode.G then
		CombatEvent:FireServer("drop")
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		CombatEvent:FireServer("sprint", true)
	elseif input.KeyCode == Enum.KeyCode.V then
		firstPerson = not firstPerson
		applyCameraMode()
	elseif input.KeyCode == Enum.KeyCode.LeftAlt then
		-- vista libre mientras mantenés Alt: la cámara gira alrededor tuyo sin mover al caballero
		freeCam.on = true
		freeCam.look = camera.CFrame.LookVector
		applyCameraMode()
	elseif input.KeyCode == Enum.KeyCode.Tab then
		refreshBoard()
		board.Visible = true
	elseif input.KeyCode == Enum.KeyCode.M then
		menuOpen = not menuOpen
		if menuOpen then
			tabs.weapon = nil -- se abre en la lista de armas, sin modelo todavía
		end
		CombatEvent:FireServer("armory", menuOpen)
	elseif input.KeyCode == Enum.KeyCode.H then
		help.Visible = not help.Visible
	elseif input.KeyCode == Enum.KeyCode.F4 then
		CombatEvent:FireServer("slowmo")
	elseif input.KeyCode == Enum.KeyCode.F3 then
		debugOn = not debugOn
		CombatEvent:FireServer("debug", debugOn)
		if not debugOn then
			for _, d in pairs(debugParts) do
				if typeof(d) == "Instance" then
					d:Destroy()
				end
			end
			debugParts = {}
		end
	elseif input.KeyCode == Enum.KeyCode.LeftBracket or input.KeyCode == Enum.KeyCode.RightBracket then
		opts.fov = math.clamp(opts.fov + (input.KeyCode == Enum.KeyCode.RightBracket and 5 or -5), 60, 120)
		fovToast = os.clock()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		CombatEvent:FireServer("unblock")
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		CombatEvent:FireServer("sprint", false)
	elseif input.KeyCode == Enum.KeyCode.Tab then
		board.Visible = false
	elseif input.KeyCode == Enum.KeyCode.LeftAlt and freeCam.on then
		freeCam.on = false -- al soltar Alt volvés a la cámara que tenías
		applyCameraMode()
	end
end)

player.CharacterAdded:Connect(function(char)
	predicted = nil
	task.defer(applyCameraMode)
end)
if player.Character then
	applyCameraMode()
end

---------------------------------------------------------------------------
-- Efectos
---------------------------------------------------------------------------
local function showTech(text, actor, other)
	if actor == player.Name or other == player.Name then
		toast.text = (actor == player.Name) and text or (text .. " RIVAL")
		toast.untilT = os.clock() + 0.9
	end
end

local function pick(list)
	return list[math.random(#list)]
end

local function sound(id, pos, volume)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Parent = workspace })
	local s = new("Sound", { SoundId = id, Volume = (volume or 0.8) * opts.volume, RollOffMaxDistance = 120, Parent = p })
	s:Play()
	Debris:AddItem(p, 3)
end

-- chispazo grande: chispas rápidas + destello + humo metálico y sacudida de cámara si estás cerca
local shake = { amount = 0 }

local function bigClash(pos, color)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Parent = workspace })
	local fast = new("ParticleEmitter", { Color = ColorSequence.new(Color3.new(1, 1, 0.85), color), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.15, 0.5), Speed = NumberRange.new(18, 40), Drag = 4, Acceleration = Vector3.new(0, -35, 0),
		SpreadAngle = Vector2.new(180, 180), Rate = 0, Orientation = Enum.ParticleOrientation.VelocityParallel, Parent = p })
	fast:Emit(60)
	local glow = new("ParticleEmitter", { Color = ColorSequence.new(color), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.12, 0.18), Speed = NumberRange.new(0, 0), Rate = 0, Parent = p })
	glow:Emit(3)
	local smoke = new("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(180, 175, 170)), LightInfluence = 1,
		Size = NumberSequence.new(0.4, 1.4), Transparency = NumberSequence.new(0.6, 1), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = p })
	smoke:Emit(6)
	local light = new("PointLight", { Color = color, Range = 14, Brightness = 6, Shadows = false, Parent = p })
	task.delay(0.08, function()
		light.Brightness = 2
	end)
	task.delay(0.16, function()
		light:Destroy()
	end)
	Debris:AddItem(p, 1.2)
	local dist = (camera.CFrame.Position - pos).Magnitude
	if dist < 18 then
		shake.amount = math.max(shake.amount, 0.35 * (1 - dist / 18))
	end
end

local function sparks(pos, color, count)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Parent = workspace })
	local e = new("ParticleEmitter", { Color = ColorSequence.new(color), LightEmission = 0.6, Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(0.2, 0.45), Speed = NumberRange.new(8, 18), SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = p })
	e:Emit(count or 18)
	Debris:AddItem(p, 1)
end

-- marca de impacto en la mira (le pegaste) y viñeta roja (te pegaron)
local hitMarker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 34, 0, 34),
	BackgroundTransparency = 1, Visible = false, Parent = gui })
for _, rot in ipairs({ 45, -45 }) do
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 4),
		Rotation = rot, BackgroundColor3 = Color3.fromRGB(255, 70, 60), BorderSizePixel = 0, Parent = hitMarker })
end
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(160, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 0, Parent = gui })
local feedbackT = { marker = 0, vignette = 0 }

local function flashCharacter(char)
	if not char or not char.Parent then
		return
	end
	local h = new("Highlight", { FillColor = Color3.fromRGB(255, 40, 30), FillTransparency = 0.35, OutlineColor = Color3.fromRGB(255, 220, 200),
		OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = char })
	task.delay(0.14, function()
		h:Destroy()
	end)
end

-- número de daño flotante
local function damageNumber(pos, amount, color)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Parent = workspace })
	local g = new("BillboardGui", { Size = UDim2.new(0, 90, 0, 40), AlwaysOnTop = true, Parent = p })
	local l = label({ Size = UDim2.fromScale(1, 1), Text = tostring(math.floor(amount + 0.5)), TextColor3 = color, MaxSize = 30, TextStrokeTransparency = 0.2, Parent = g })
	task.spawn(function()
		for i = 1, 30 do
			p.CFrame = p.CFrame + Vector3.new(0, 0.06, 0)
			l.TextTransparency = i / 30
			l.TextStrokeTransparency = 0.2 + 0.8 * i / 30
			task.wait(1 / 60)
		end
		p:Destroy()
	end)
end

FxEvent.OnClientEvent:Connect(function(kind, a, b, c, d, e, g)
	if kind == "hit" then
		sparks(a, Color3.fromRGB(170, 20, 20), 22)
		sound(pick(d == "blunt" and SOUNDS.blunt or SOUNDS.cut), a, 1)
		damageNumber(a, c or 0, b == "head" and Color3.fromRGB(255, 200, 60) or Color3.new(1, 1, 1))
		-- el que recibe parpadea en rojo y retrocede; el que pega ve la marca en la mira y un temblor corto
		flashCharacter(g)
		if g then
			local kd = knights[g]
			if kd then
				kd.flinchAt = os.clock()
			end
		end
		if e == player.Name then
			feedbackT.marker = os.clock()
			shake.amount = math.max(shake.amount, 0.18)
			sparks(a, Color3.fromRGB(255, 60, 40), 30)
		elseif g == player.Character then
			feedbackT.vignette = os.clock()
			shake.amount = math.max(shake.amount, 0.3)
		end
	elseif kind == "dummyreset" then
		showTech("¡DUMMY DERROTADO!", b, nil)
	elseif kind == "tech" then
		showTech(c, b, nil)
	elseif kind == "parry" or kind == "chamber" then
		showTech(kind == "chamber" and "CHAMBER" or "PARRY", b, nil)
		bigClash(a, Color3.fromRGB(255, 200, 90))
		sound(pick(SOUNDS.parry), a, 1.2)
		if kind == "chamber" then
			sound(pick(SOUNDS.clash), a, 1)
		end
	elseif kind == "weaponclash" then
		showTech("CLASH", b, c)
		bigClash(a, Color3.fromRGB(255, 230, 150))
		sound(pick(SOUNDS.parry), a, 1.3)
		sound(pick(SOUNDS.clash), a, 1.1)
	elseif kind == "block" then
		sparks(a, Color3.fromRGB(255, 220, 120), 14)
		sound(pick(SOUNDS.block), a, 1)
	elseif kind == "clash" then
		sparks(a, Color3.fromRGB(230, 230, 230), 10)
		sound(pick(SOUNDS.clash), a, 0.8)
	elseif kind == "kick" then
		sound(pick(SOUNDS.kick), a, 1)
	elseif kind == "combo" then
		showTech("COMBO", b, nil)
	elseif kind == "feint" then
		showTech(c or "FINTA", b, nil)
	elseif kind == "drop" or kind == "pickup" then
		sound(pick(SOUNDS.disarm), a, 0.8)
	elseif kind == "death" then
		sound(pick(SOUNDS.death), a, 1)
	elseif kind == "disarm" then
		sparks(a, Color3.fromRGB(255, 160, 60), 30)
		sound(pick(SOUNDS.disarm), a, 1)
	elseif kind == "dbgBlade" then
		if debugOn then
			debugParts.server = debugParts.server or new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 60, 60), Transparency = 0.2, Parent = workspace })
			local len = (b - a).Magnitude
			debugParts.server.Size = Vector3.new(0.06, 0.06, len)
			debugParts.server.CFrame = CFrame.lookAt((a + b) / 2, b)
		end
	elseif kind == "dbgHit" then
		if debugOn then
			local len = (b - a).Magnitude
			local ray = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 60),
				Size = Vector3.new(0.05, 0.05, math.max(len, 0.05)), CFrame = CFrame.lookAt((a + b) / 2, b), Parent = workspace })
			local dot = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
				Color = c and Color3.fromRGB(255, 230, 60) or Color3.fromRGB(120, 200, 255), Size = Vector3.one * 0.35, CFrame = CFrame.new(b), Parent = workspace })
			Debris:AddItem(ray, 3)
			Debris:AddItem(dot, 3)
		end
	elseif kind == "kill" then
		local killer, victim, weaponName = a, b, c
		if killer ~= "" and killer ~= victim then
			feedLine(string.format("%s  [%s]  %s", killer, weaponName, victim), (killer == player.Name or victim == player.Name) and GOLD or WHITE)
		else
			feedLine(victim .. " murió", Color3.fromRGB(200, 200, 200))
		end
	end
end)

---------------------------------------------------------------------------
-- Bucles
---------------------------------------------------------------------------
-- brazos, piernas y armas: después de la animación y antes de la física de cada cuadro
RunService.Stepped:Connect(function(_, dt)
	local t = serverNow()
	local alive = {}
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("MordoxBots")
	for _, c in ipairs(bots and bots:GetChildren() or {}) do
		table.insert(chars, c)
	end
	for _, char in ipairs(chars) do
		alive[char] = true
		pcall(animateKnight, char, t, dt)
	end
	for char, k in pairs(knights) do
		if type(char) ~= "string" and not alive[char] then
			destroyWeapon(k.weapon)
			knights[char] = nil
		elseif type(char) ~= "string" and char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").Health <= 0 and k.weapon then
			destroyWeapon(k.weapon)
			k.weapon, k.weaponId = nil, nil
		end
	end
end)

-- armas tiradas en el piso: cada pieza física lleva su modelo dibujado encima
local droppedViews = {}

local function updateDropped()
	local folder = workspace:FindFirstChild("MordoxDropped")
	local alive = {}
	for _, part in ipairs(folder and folder:GetChildren() or {}) do
		if part:IsA("BasePart") then
			alive[part] = true
			local view = droppedViews[part]
			local id = part:GetAttribute("Weapon") or "espadon"
			if not view then
				local w = Config.Weapon(id)
				local sty = {}
				for key in pairs(Config.DefaultWeaponStyle(w.Id)) do
					sty[key] = part:GetAttribute(key)
				end
				view = { model = buildWeapon(w, sty), weapon = w }
				droppedViews[part] = view
			end
			-- la pieza física es el eje del arma: la empuñadura queda en un extremo
			local w = view.weapon
			placeParts(view.model.parts, part.CFrame * CFrame.new(0, 0, (w.Length + w.Grip) / 2 - w.Grip))
		end
	end
	for part, view in pairs(droppedViews) do
		if not alive[part] then
			destroyWeapon(view.model)
			droppedViews[part] = nil
		end
	end
end

-- primera persona: mostrar brazos propios (después de que la cámara de Roblox oculta el cuerpo)
RunService:BindToRenderStep("MordoxArms", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local char = player.Character
	local k = char and knights[char]
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	updateDropped()
	-- el arma propia se dibuja con la cámara de este mismo cuadro: el drag y el accel se ven al instante
	if k and hrp and k.weapon and k.weaponDef then
		local look = aimLook()
		local body = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		local pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
		local st = poseState(readState(char), k.weaponDef, serverNow())
		local base, tip, dir, edge = Swing.WorldPose(body, pitch, k.weaponDef, st)
		k.debugBase, k.debugTip, k.debugBody, k.debugSt = base, tip, body, st -- la línea de F3 muestra la hoja real, sin suavizar
		k.smView = k.smView or {}
		base, tip, dir, edge = smoothWeapon(k.smView, body, base, dir, st, dt, k.weaponDef.Length, edge)
		placeParts(k.weapon.parts, CFrame.lookAt(base, base + dir, edge))
		-- tope de giro durante carga y golpe: baja la sensibilidad si girás más rápido que el límite
		local yaw = math.atan2(-look.X, -look.Z)
		local attacking = st.State == "attack" and st.Phase ~= "recovery"
		if turn.yaw and dt > 0 then
			local rate = math.deg(math.abs((yaw - turn.yaw + math.pi) % (2 * math.pi) - math.pi)) / dt
			turn.rate = rate
			local target = attacking and Config.Combat.AttackSensitivity or 1
			if attacking and rate > Config.Combat.TurnCap then
				target = math.clamp(math.min(target, turn.sens * Config.Combat.TurnCap / rate), 0.15, 1)
			end
			turn.sens += (target - turn.sens) * (attacking and 0.6 or 0.2)
			UserInputService.MouseDeltaSensitivity = turn.sens * opts.sens
		end
		turn.yaw = yaw
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	UserInputService.MouseBehavior = loadout.Visible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = loadout.Visible -- el puntero solo aparece para elegir arma

	-- tercera persona: el cuerpo mira hacia donde apunta la cámara
	if hrp and hum and not firstPerson and not freeCam.on and hum.Health > 0 then
		local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look.Unit)
		end
	end

	-- mirada vertical (para inclinar los golpes)
	if char then
		local k = knights[char]
		local pitch = math.deg(math.asin(math.clamp(aimLook().Y, -1, 1)))
		if k then
			k.localPitch = pitch
		end
		if os.clock() - lastPitchSent > 1 / 30 then
			lastPitchSent = os.clock()
			local look = aimLook()
			LookEvent:FireServer(math.atan2(-look.X, -look.Z), pitch)
		end
	end

	camera.FieldOfView = opts.fov
	local mk = os.clock() - feedbackT.marker
	hitMarker.Visible = mk < 0.25
	hitMarker.Size = UDim2.new(0, 34 + (1 - math.clamp(mk / 0.25, 0, 1)) * 16, 0, 34 + (1 - math.clamp(mk / 0.25, 0, 1)) * 16)
	vignette.BackgroundTransparency = 1 - 0.35 * math.clamp(1 - (os.clock() - feedbackT.vignette) / 0.35, 0, 1)
	if TS() > 1 then
		topBar.TextColor3 = Color3.fromRGB(120, 200, 255)
	else
		topBar.TextColor3 = WHITE
	end
	if shake.amount > 0.001 then
		local a = shake.amount
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * 6 * a), math.rad((math.random() - 0.5) * 6 * a), 0)
		shake.amount = a * math.exp(-dt * 14)
	end
	if os.clock() - fovToast < 1.2 then
		stateText.Text = "FOV " .. opts.fov
	end
	-- modo desarrollador (F3): hoja local (verde), rastro de la punta, hoja del servidor (rojo), cajas de golpe y datos
	debugText.Visible = debugOn
	if debugOn and char then
		local k = knights[char]
		if k and k.debugBase then
			debugParts.blade = debugParts.blade or new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
				Color = Color3.fromRGB(80, 255, 120), Transparency = 0.2, Parent = workspace })
			local len = (k.debugTip - k.debugBase).Magnitude
			debugParts.blade.Size = Vector3.new(0.05, 0.05, len)
			debugParts.blade.CFrame = CFrame.lookAt((k.debugBase + k.debugTip) / 2, k.debugTip)
			-- rastro de la punta coloreado según drag/accel: velocidad real de la punta contra la que tendría sin mover la cámara
			local tipLocal = k.debugBody:PointToObjectSpace(k.debugTip)
			local trailColor = Color3.fromRGB(230, 230, 230)
			if k.lastTip and k.lastTipLocal and k.debugSt and k.debugSt.State == "attack" and k.debugSt.Phase == "release" then
				local expected = (tipLocal - k.lastTipLocal).Magnitude
				local actual = (k.debugTip - k.lastTip).Magnitude
				local ratio = expected > 1e-3 and actual / expected or 1
				k.tipRatio = (k.tipRatio or 1) + (ratio - (k.tipRatio or 1)) * 0.3
				if k.tipRatio > 1.12 then
					local x = math.clamp((k.tipRatio - 1.12) / 0.8, 0, 1)
					trailColor = Color3.fromRGB(255, 200 - 170 * x, 40) -- accel: amarillo a rojo
				elseif k.tipRatio < 0.88 then
					local x = math.clamp((0.88 - k.tipRatio) / 0.6, 0, 1)
					trailColor = Color3.fromRGB(120 - 100 * x, 200 - 80 * x, 255) -- drag: celeste a azul
				else
					trailColor = Color3.fromRGB(120, 255, 140) -- sin mover la cámara
				end
			end
			k.lastTipLocal = tipLocal
			if k.lastTip and (k.lastTip - k.debugTip).Magnitude > 0.05 then
				local seg = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = trailColor,
					Transparency = 0.3, Size = Vector3.new(0.04, 0.04, (k.lastTip - k.debugTip).Magnitude),
					CFrame = CFrame.lookAt((k.lastTip + k.debugTip) / 2, k.debugTip), Parent = workspace })
				Debris:AddItem(seg, 1.2)
			end
			k.lastTip = k.debugTip
		end
		local st2 = k and k.st
		debugText.Text = string.format("MODO DESARROLLADOR\nestado  %s %s  T=%.2f\nángulo  %d   tipo %s\nstamina %s\nping    %d ms\ngiro    %.0f°/s (tope %d)\nsens.   %.2f\nFOV     %d\nhoja: verde local · roja servidor\nrastro: verde normal · amarillo/rojo ACCEL · celeste/azul DRAG\nvelocidad punta x%.2f  %s",
			st2 and st2.State or "-", st2 and st2.Phase or "", st2 and st2.T or 0, st2 and st2.Angle or 0, st2 and st2.Kind or "",
			tostring(char:GetAttribute("Stamina")), math.floor(player:GetNetworkPing() * 1000),
			turn.rate, Config.Combat.TurnCap, turn.sens, opts.fov, k and k.tipRatio or 1,
			not (k and k.tipRatio) and "" or k.tipRatio > 1.12 and "ACCEL" or k.tipRatio < 0.88 and "DRAG" or "")
	elseif not debugOn then
		for _, p in ipairs(Players:GetPlayers()) do
			local c3 = p.Character
			if c3 then
				for _, sb in ipairs(c3:GetChildren()) do
					if sb.Name == "MordoxHitbox" then
						sb:Destroy()
					end
				end
			end
		end
	end

	-- HUD
	healthFill.Size = UDim2.fromScale(hum and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0, 1)
	staminaFill.Size = UDim2.fromScale(char and (char:GetAttribute("Stamina") or 100) / Config.Stamina.Max or 0, 1)
	local angle = currentAngle()
	arrow.Position = UDim2.new(0.5, math.sin(math.rad(angle)) * 26, 0.5, -math.cos(math.rad(angle)) * 26)
	arrow.Rotation = angle
	local st = char and char:GetAttribute("St") or ""
	local combo = char and char:GetAttribute("Combo") or 0
	local unarmed = char and char:GetAttribute("Unarmed")
	local riposteOpen = st == "riposte" or (st == "block" and serverNow() <= (char:GetAttribute("RiposteUntil") or 0))
	stateText.Text = freeCam.on and "VISTA LIBRE · soltá Alt para volver"
		or unarmed and "SIN ARMA · G para levantar una del piso" or riposteOpen and "¡RIPOSTE! (atacá ya)" or os.clock() < toast.untilT and toast.text or combo >= 1 and st == "attack" and ("COMBO x" .. (combo + 1)) or st == "riposte" and "¡RIPOSTE!" or st == "disarmed" and "DESARMADO" or st == "stun" and "" or st == "block" and "BLOQUEANDO" or ""

	local dead = not hum or hum.Health <= 0
	if dead and not wasDead then
		menuOpen = true -- al morir se abre la armería y la reaparición espera
		tabs.weapon = nil
		CombatEvent:FireServer("armory", true)
	elseif not dead and wasDead then
		menuOpen = false
	end
	wasDead = dead
	loadout.Visible = dead or menuOpen
	deathText.Visible = false
	if loadout.Visible then
		local gear = gearOf(player.Character)
		local shownId = tabs.weapon or player:GetAttribute("Weapon") or Config.Weapons[1].Id
		local wsty = weaponStyleOf(player.Character, shownId)
		local function mark(buttons, chosenId, opt)
			for id, b in pairs(buttons) do
				local chosen = id == chosenId
				b.BackgroundColor3 = (opt and opt(id) and opt(id).Color) or (chosen and Color3.fromRGB(120, 80, 30) or Color3.fromRGB(45, 37, 30))
				local stroke = b:FindFirstChildOfClass("UIStroke") or new("UIStroke", { Color = GOLD, Thickness = 2, Parent = b })
				stroke.Enabled = chosen
			end
		end
		for key, buttons in pairs(gearButtons) do
			mark(buttons, gear[key], function(id)
				return Config.GearOption(key, id)
			end)
		end
		for key, buttons in pairs(styleButtons) do
			mark(buttons, wsty[key], function(id)
				return Config.WeaponOption(shownId, key, id)
			end)
		end
		local forging = tabs.current == "arma" and tabs.weapon ~= nil
		if forging and builtRowsFor ~= tabs.weapon then
			buildWeaponRows(tabs.weapon) -- las piezas son las de esta arma
		end
		for _, r in ipairs(tabs.rows) do
			r.row.Visible = r.tab == tabs.current and (r.tab ~= "arma" or forging)
		end
		weaponList.Visible = tabs.current == "arma" and not forging
		local myWeapon = player:GetAttribute("Weapon")
		for id, b in pairs(weaponButtons) do
			local equipped = id == myWeapon
			b.BackgroundColor3 = equipped and Color3.fromRGB(120, 80, 30) or Color3.fromRGB(45, 37, 30)
			local tag = b:FindFirstChild("Equipada")
			if not tag then
				tag = label({ Name = "Equipada", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.new(0, 120, 0, 24),
					Text = "EQUIPADA", TextColor3 = GOLD, MaxSize = 16, Font = FONT2, TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
			end
			tag.Visible = equipped
		end
		backButton.Visible = forging
		for id, b in pairs(tabs.buttons) do
			b.BackgroundColor3 = id == tabs.current and Color3.fromRGB(120, 80, 30) or Color3.fromRGB(45, 37, 30)
		end
		swordVp.Visible = forging
		knightVp.Visible = tabs.current == "equipo"
		emptyView.Visible = not swordVp.Visible and not knightVp.Visible
		emptyView.Text = tabs.current == "ajustes" and "Ajustes del juego" or "Elegí un arma para verla y forjarla"
		if forging or tabs.current == "equipo" then
			local shown = Config.Weapon(shownId)
			refreshPreview(gear, shown, wsty)
			weaponFoot.Text = string.format("%s · daño %d al tajo · alcance %.1f · carga %.2f s", shown.Name:upper(), shown.Slash.Damage,
				shown.Length, shown.Slash.Windup)
		end
		if preview.weapon then
			local turn = CFrame.Angles(0, swordView.yaw, 0) * CFrame.Angles(swordView.pitch, 0, 0)
			placeParts(preview.weapon.parts, turn * CFrame.new(0, swordView.offset or 0, 0) * CFrame.Angles(math.rad(90), 0, 0))
			swordCam.CFrame = CFrame.lookAt(Vector3.new(0, 0, swordView.dist * swordView.zoom), Vector3.new())
		end
		if knightVp.Visible and avatarPreview.model then
			local turn = CFrame.Angles(0, knightView.yaw, 0) * CFrame.Angles(knightView.pitch * 0.35, 0, 0)
			local c = avatarPreview.center or Vector3.new()
			avatarPreview.model:PivotTo(turn * CFrame.new(-c)) -- gira sobre el centro del cuerpo
			knightCam.CFrame = CFrame.lookAt(Vector3.new(0, 0, knightView.dist * knightView.zoom), Vector3.new())
		end
		armorStats.Visible = tabs.current == "equipo"
		armorStats.Text = armorSummary(gear)
		local wait = (char and char:GetAttribute("CanSpawnAt") or 0) - serverNow()
		local ready = not dead or wait <= 0
		spawnButton.BackgroundColor3 = ready and Color3.fromRGB(120, 80, 30) or Color3.fromRGB(60, 52, 44)
		spawnLabel.Text = not dead and "VOLVER AL COMBATE" or (ready and "SALIR AL CAMPO" or string.format("ESPERÁ %.0f s", math.max(wait, 0)))
	end

	local phase = matchInfo:GetAttribute("Phase")
	local left = math.max(0, (matchInfo:GetAttribute("EndsAt") or 0) - serverNow())
	if phase == "intermission" then
		topBar.Text = string.format("Nueva partida en %d", math.ceil(left))
		local winner = matchInfo:GetAttribute("Winner") or ""
		banner.Visible = winner ~= ""
		banner.Text = winner ~= "" and ("GANADOR: " .. winner) or ""
	else
		banner.Visible = false
		local s = player:FindFirstChild("leaderstats")
		topBar.Text = (TS() > 1 and "CÁMARA LENTA   ·   " or "") .. string.format("%d:%02d   ·   Kills %d / %d", math.floor(left / 60), math.floor(left % 60), s and s.Kills.Value or 0, Config.Match.KillLimit)
	end
end)
