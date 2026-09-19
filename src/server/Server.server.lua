-- Mordox · servidor
-- Mapa, caballeros, partida todos contra todos y combate con autoridad del servidor
-- (estados, stamina, detección de impactos a lo largo de la hoja, parry, chamber, feint, morph, patada y desarme).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("MordoxConfig"))
local Swing = require(ReplicatedStorage:WaitForChild("Swing"))
local Armor = require(ReplicatedStorage:WaitForChild("MordoxArmor"))

Players.CharacterAutoLoads = false

---------------------------------------------------------------------------
-- Remotes y estado de la partida
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "MordoxRemotes"
local CombatEvent = Instance.new("RemoteEvent")
CombatEvent.Name = "Combat"
CombatEvent.Parent = remotes
local FxEvent = Instance.new("RemoteEvent")
FxEvent.Name = "Fx"
FxEvent.Parent = remotes
-- mirada del jugador 30 veces por segundo (canal rápido, se puede perder alguno): orienta el barrido de la hoja
local LookEvent = Instance.new("UnreliableRemoteEvent")
LookEvent.Name = "Look"
LookEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local matchInfo = Instance.new("Folder")
matchInfo.Name = "MordoxMatch"
matchInfo.Parent = ReplicatedStorage

local function now()
	return workspace:GetServerTimeNow()
end

-- cámara lenta: multiplica la duración de todas las fases del combate
local function TS()
	return matchInfo:GetAttribute("TimeScale") or 1
end
matchInfo:SetAttribute("TimeScale", 1)

-- velocidad de movimiento: la base, por el peso de la armadura, y en cámara lenta
local function speed(f, base)
	return base * (f.speedMul or 1) / TS()
end

---------------------------------------------------------------------------
-- Mapa: patio de castillo
---------------------------------------------------------------------------
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or map
	return p
end

local STONE = Color3.fromRGB(120, 115, 108)
local DARK_STONE = Color3.fromRGB(85, 80, 76)
local WOOD = Color3.fromRGB(105, 72, 44)
local HALF = 110

part({ Name = "Ground", Size = Vector3.new(HALF * 2 + 40, 2, HALF * 2 + 40), CFrame = CFrame.new(0, -1, 0),
	Color = Color3.fromRGB(92, 84, 70), Material = Enum.Material.Cobblestone })

-- murallas con almenas y torres en las esquinas
for _, side in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
	local along = side[1] == 0
	local len = HALF * 2
	local pos = Vector3.new(side[1] * HALF, 11, side[2] * HALF)
	part({ Name = "Wall", Size = along and Vector3.new(len, 22, 4) or Vector3.new(4, 22, len), CFrame = CFrame.new(pos),
		Color = STONE, Material = Enum.Material.Brick })
	for i = -HALF + 4, HALF - 4, 8 do
		local offset = along and Vector3.new(i, 12.5, 0) or Vector3.new(0, 12.5, i)
		part({ Name = "Merlon", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(pos + offset), Color = STONE, Material = Enum.Material.Brick })
	end
end
for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
	local base = Vector3.new(c[1] * HALF, 0, c[2] * HALF)
	part({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 16, 16),
		CFrame = CFrame.new(base + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK_STONE, Material = Enum.Material.Brick })
	part({ Name = "TowerRoof", Size = Vector3.new(18, 2, 18), CFrame = CFrame.new(base + Vector3.new(0, 35, 0)), Color = Color3.fromRGB(70, 40, 35) })
end

-- torreón en ruinas en el centro
local keep = Vector3.new(0, 0, 0)
for _, w in ipairs({ { Vector3.new(0, 7, -14), Vector3.new(30, 14, 3) }, { Vector3.new(-14, 5, 0), Vector3.new(3, 10, 22) },
	{ Vector3.new(14, 9, 4), Vector3.new(3, 18, 16) } }) do
	part({ Name = "KeepWall", Size = w[2], CFrame = CFrame.new(keep + w[1]), Color = DARK_STONE, Material = Enum.Material.Slate })
end
part({ Name = "KeepStairs", Size = Vector3.new(10, 1, 14), CFrame = CFrame.new(-4, 3, 6) * CFrame.Angles(math.rad(-25), 0, 0),
	Color = STONE, Material = Enum.Material.Slate })

-- arcos, empalizadas, cajas y fardos
local function arch(pos, rotY)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rotY, 0)
	part({ Name = "Arch", Size = Vector3.new(3, 14, 3), CFrame = cf * CFrame.new(-6, 7, 0), Color = STONE, Material = Enum.Material.Brick })
	part({ Name = "Arch", Size = Vector3.new(3, 14, 3), CFrame = cf * CFrame.new(6, 7, 0), Color = STONE, Material = Enum.Material.Brick })
	part({ Name = "Arch", Size = Vector3.new(15, 3, 3), CFrame = cf * CFrame.new(0, 15, 0), Color = STONE, Material = Enum.Material.Brick })
end
arch(Vector3.new(0, 0, 55), 0)
arch(Vector3.new(0, 0, -55), 0)
arch(Vector3.new(55, 0, 0), math.rad(90))
arch(Vector3.new(-55, 0, 0), math.rad(90))

local rng = Random.new(7)
for _ = 1, 14 do
	local x, z = rng:NextNumber(-HALF + 15, HALF - 15), rng:NextNumber(-HALF + 15, HALF - 15)
	if math.abs(x) > 22 or math.abs(z) > 22 then
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for i = 0, rng:NextInteger(1, 3) do
			part({ Name = "Crate", Size = Vector3.new(3.5, 3.5, 3.5), CFrame = cf * CFrame.new(i * 3.8, 1.75, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
		end
	end
end
for _ = 1, 10 do
	local x, z = rng:NextNumber(-HALF + 12, HALF - 12), rng:NextNumber(-HALF + 12, HALF - 12)
	if math.abs(x) > 22 or math.abs(z) > 22 then
		part({ Name = "Hay", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(x, 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Grass })
	end
end
for _, p in ipairs({ { -70, 30 }, { 70, -30 } }) do
	for i = 0, 8 do
		part({ Name = "Palisade", Size = Vector3.new(1.4, 9, 1.4), CFrame = CFrame.new(p[1] + i * 1.5, 4.5, p[2]), Color = WOOD, Material = Enum.Material.Wood })
	end
end

-- antorchas
for i = 0, 15 do
	local a = i / 16 * math.pi * 2
	local pos = Vector3.new(math.cos(a) * (HALF - 3), 8, math.sin(a) * (HALF - 3))
	local torch = part({ Name = "Torch", Size = Vector3.new(0.6, 2, 0.6), CFrame = CFrame.new(pos), Color = WOOD, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = torch
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 22
	light.Brightness = 1.6
	light.Parent = torch
end

Lighting.ClockTime = 18.3
Lighting.Brightness = 1.6
Lighting.Ambient = Color3.fromRGB(70, 60, 60)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 95, 90)
Lighting.FogColor = Color3.fromRGB(120, 100, 90)
Lighting.FogEnd = 600

local spawns = {}
for i = 1, 16 do
	local a = i / 16 * math.pi * 2
	local r = (i % 2 == 0) and 85 or 40
	table.insert(spawns, CFrame.lookAt(Vector3.new(math.cos(a) * r, 4, math.sin(a) * r), Vector3.new(0, 4, 0)))
end

---------------------------------------------------------------------------
-- Caballero: tu propio avatar (R15) con la armadura elegida encima
---------------------------------------------------------------------------
local descriptions = {} -- [userId] = HumanoidDescription (se pide una sola vez)

local function descriptionFor(userId)
	if descriptions[userId] then
		return descriptions[userId]
	end
	local desc
	if userId and userId > 0 then
		pcall(function()
			desc = Players:GetHumanoidDescriptionFromUserId(userId)
		end)
	end
	desc = desc or Instance.new("HumanoidDescription")
	-- la animación la hace el juego: fuera las animaciones del avatar
	for _, prop in ipairs({ "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation" }) do
		pcall(function()
			desc[prop] = 0
		end)
	end
	descriptions[userId] = desc
	return desc
end

-- arma el muñeco R15 del avatar listo para pelear (sin scripts de animación, sin romperse al morir)
local function buildAvatar(userId, name)
	local rig = Players:CreateHumanoidModelFromDescription(descriptionFor(userId), Enum.HumanoidRigType.R15)
	rig.Name = name
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			if d.Name == "Animate" then
				d:Destroy() -- brazos y piernas se animan por código en el cliente
			end
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = Config.MaxHealth
	hum.Health = Config.MaxHealth
	hum.WalkSpeed = Config.WalkSpeed
	hum.BreakJointsOnDeath = false
	return rig
end

-- muñeco quieto del avatar para la vista previa de la armería (el cliente le pone la armadura)
local previews = Instance.new("Folder")
previews.Name = "MordoxPreviews"
previews.Parent = ReplicatedStorage

local function publishPreview(player)
	local old = previews:FindFirstChild(tostring(player.UserId))
	if old then
		return
	end
	local ok, rig = pcall(buildAvatar, player.UserId, tostring(player.UserId))
	if ok and rig then
		rig.Parent = previews
	end
end

---------------------------------------------------------------------------
-- Combate
---------------------------------------------------------------------------
local fighters = {} -- [player] = estado (los bots usan una carpeta como "jugador")
local fighterByChar = setmetatable({}, { __mode = "k" })

local function setAttr(f)
	local char = f.char
	if not char then
		return
	end
	char:SetAttribute("St", f.state)
	char:SetAttribute("Kind", f.kind or "")
	char:SetAttribute("Angle", f.angle or 0)
	char:SetAttribute("Phase", f.phase or "")
	char:SetAttribute("PhaseStart", f.phaseStart or 0)
	char:SetAttribute("PhaseDur", f.phaseDur or 0)
	char:SetAttribute("Weapon", f.weapon.Id)
	char:SetAttribute("Stamina", math.floor(f.stamina + 0.5))
end

local function setState(f, state, dur)
	f.state = state
	f.phase = ""
	f.phaseStart = now()
	f.phaseDur = (dur or 0) * TS()
	f.kind = nil
	setAttr(f)
end

local function spendStamina(f, amount)
	f.stamina = math.max(0, f.stamina - amount)
	f.lastSpend = now()
end

local function attackData(f)
	return f.kind == "stab" and f.weapon.Stab or f.weapon.Slash
end

local function startPhase(f, phase, dur)
	f.phase = phase
	f.phaseStart = now()
	f.phaseDur = dur * TS()
	setAttr(f)
end

local function startAttack(f, kind, angle, windupScale, flags)
	f.state = "attack"
	f.kind = kind
	f.angle = angle
	f.hitDone = false
	f.prevPoints = nil
	f.isRiposte = flags and flags.riposte or false
	f.attackStart = now()
	f.hitSomething = false
	f.chambered, f.morphed = false, false
	f.queued = nil
	if f.char then
		f.char:SetAttribute("CanCombo", false)
	end
	startPhase(f, "windup", attackData(f).Windup * (windupScale or 1))
	if f.hum then
		f.hum.WalkSpeed = speed(f, Config.AttackMoveSpeed)
	end
end

-- combo (como Mordhau): desde el final del golpe o la recuperación, pegue o no; cuesta stamina creciente
local function tryCombo(f, kind, angle)
	local S = Config.Stamina
	local cost = S.Combo + S.ComboStep * (f.comboCount or 0)
	if f.stamina < math.max(S.ComboMin, cost) then
		return false
	end
	spendStamina(f, cost)
	local count = (f.comboCount or 0) + 1
	startAttack(f, kind, angle, Config.Combat.ComboWindupScale)
	f.comboCount = count
	f.char:SetAttribute("Combo", count)
	FxEvent:FireAllClients("combo", f.char.HumanoidRootPart.Position, count)
	return true
end

local function toIdle(f)
	f.comboCount = 0
	f.bufferedCombo = nil
	if f.char then
		f.char:SetAttribute("Combo", 0)
	end
	setState(f, "idle")
	if f.hum then
		f.hum.WalkSpeed = speed(f, f.sprint and Config.SprintSpeed or Config.WalkSpeed)
	end
end

local function zoneOf(partName)
	if partName == "Head" or partName == "Helmet" or partName == "Visor" or partName == "Crest" then
		return "head"
	elseif partName:find("Leg") or partName:find("Foot") or partName == "Greave" then
		return "legs"
	end
	return "torso"
end

local function fighterOfPart(p)
	local model = p:FindFirstAncestorOfClass("Model")
	while model and not fighterByChar[model] and model.Parent and model.Parent:IsA("Model") do
		model = model.Parent
	end
	return model and fighterByChar[model]
end

local function facing(defender, attacker)
	local dhrp, ahrp = defender.char.HumanoidRootPart, attacker.char.HumanoidRootPart
	local to = (ahrp.Position - dhrp.Position) * Vector3.new(1, 0, 1)
	if to.Magnitude < 1e-3 then
		return 1
	end
	return dhrp.CFrame.LookVector:Dot(to.Unit)
end

local dropWeapon, pickUpWeapon -- se definen más abajo (las usa la muerte y el desarme)

local function killed(victim, killer, weaponName)
	if victim.dead then
		return
	end
	victim.dead = true
	dropWeapon(victim, false) -- se te cae donde caíste
	setState(victim, "dead")
	local vs = victim.player:FindFirstChild("leaderstats")
	if vs then
		vs.Deaths.Value += 1
	end
	if killer and killer ~= victim then
		local ks = killer.player:FindFirstChild("leaderstats")
		if ks then
			ks.Kills.Value += 1
		end
	end
	FxEvent:FireAllClients("kill", killer and killer.player.Name or "", victim.player.Name, weaponName or "")
	local vhrp = victim.char and victim.char:FindFirstChild("HumanoidRootPart")
	if vhrp then
		FxEvent:FireAllClients("death", vhrp.Position)
	end
end

local function applyDamage(attacker, defender, amount, zone, hitPos)
	local hum = defender.hum
	if not hum or hum.Health <= 0 then
		return
	end
	defender.lastHitBy = attacker
	amount = amount * ((defender.armorMul and defender.armorMul[zone]) or 1) -- la armadura de esa zona frena parte del golpe
	FxEvent:FireAllClients("hit", hitPos, zone, amount, attacker.weapon.Slash.Type, attacker.player.Name, defender.char)
	if attacker.isBot and not Config.Match.BotsDealDamage then
		amount = 0 -- práctica: el dummy no saca vida
	end
	if defender.isBot and Config.Match.BotsImmortal then
		-- práctica: la vida del dummy es solo visual y se recarga al llegar a 0
		local left = hum.Health - amount
		if left <= 0 then
			hum.Health = hum.MaxHealth
			FxEvent:FireAllClients("dummyreset", hitPos, attacker.player.Name)
		else
			hum.Health = left
		end
	elseif amount > 0 then
		hum:TakeDamage(amount)
	end
	if hum.Health <= 0 then
		killed(defender, attacker, attacker.weapon.Name)
		return
	end
	-- el golpe interrumpe cargas, parrys y patadas (no el golpe ya lanzado)
	if not (defender.state == "attack" and defender.phase == "release") then
		setState(defender, "stun", Config.Combat.HitStun)
	end
end

local function bounce(f)
	f.state = "attack"
	f.hitDone = true
	startPhase(f, "recovery", Config.Combat.BounceRecovery)
end

-- Armas en el piso: una pieza física con los datos del arma; cada cliente le dibuja el modelo encima
local droppedFolder = Instance.new("Folder")
droppedFolder.Name = "MordoxDropped"
droppedFolder.Parent = workspace

function dropWeapon(f, throw)
    if f.unarmed or not f.char or not f.weapon then
        return
    end
    local hrp = f.char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local w = f.weapon
    local part = Instance.new("Part")
    part.Name = "Dropped"
    part.Size = Vector3.new(0.3, 0.3, w.Length + w.Grip)
    part.Color = w.Color
    part.Material = Enum.Material.Metal
    part.CanCollide = true
    part.CFrame = hrp.CFrame * CFrame.new(0, 0.5, -2) * CFrame.Angles(math.rad(70), 0, 0)
    part.Transparency = 1 -- el modelo lo dibuja el cliente encima
    part:SetAttribute("Weapon", w.Id)
    if f.player:IsA("Player") then
        for key in pairs(Config.DefaultWeaponStyle(w.Id)) do
            part:SetAttribute(key, f.player:GetAttribute("W" .. w.Id .. "_" .. key))
        end
    end
    part.Parent = droppedFolder
    -- sale volando y girando, después queda tirada donde cae
    local look = hrp.CFrame.LookVector
    part.AssemblyLinearVelocity = look * (throw and 34 or 14) + Vector3.new(0, 12, 0)
    part.AssemblyAngularVelocity = Vector3.new(math.random(-14, 14), math.random(-8, 8), math.random(-14, 14))
    f.unarmed = true
    f.char:SetAttribute("Unarmed", true)
    if f.state == "attack" or f.state == "block" or f.state == "parry" then
        toIdle(f)
    end
    FxEvent:FireAllClients("drop", part.Position)
    return part
end

function pickUpWeapon(f)
    if not f.char then
        return false
    end
    local hrp = f.char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end
    local best, bestDist
    for _, part in ipairs(droppedFolder:GetChildren()) do
        local d = (part.Position - hrp.Position).Magnitude
        if d <= 9 and (not bestDist or d < bestDist) then
            best, bestDist = part, d
        end
    end
    if not best then
        return false
    end
    local id = best:GetAttribute("Weapon")
    f.weapon = Config.Weapon(id)
    f.nextWeapon = f.weapon
    if f.player:IsA("Player") then
        f.player:SetAttribute("Weapon", f.weapon.Id)
        for key in pairs(Config.DefaultWeaponStyle(f.weapon.Id)) do
            local v = best:GetAttribute(key)
            if type(v) == "string" then
                f.player:SetAttribute("W" .. f.weapon.Id .. "_" .. key, v)
            end
        end
    end
    f.unarmed = false
    f.char:SetAttribute("Unarmed", false)
    setAttr(f)
    best:Destroy()
    FxEvent:FireAllClients("pickup", hrp.Position)
    return true
end

local function disarm(f)
	setState(f, "disarmed", Config.Stamina.DisarmTime)
	dropWeapon(f, true) -- el arma sale despedida
	FxEvent:FireAllClients("disarm", f.char.HumanoidRootPart.Position)
end

-- resuelve el impacto de "a" sobre "d"
local function resolveHit(a, d, hitPart, hitPos)
	local data = attackData(a)
	local c = Config.Combat
	-- parry (o escudo) de frente
	local blocking = d.state == "parry" or d.state == "block"
	if blocking and facing(d, a) >= (d.state == "block" and c.ShieldCone or c.ParryCone) then
		local drain = d.state == "block" and (d.weapon.ShieldDrainPerHit or 10) or a.weapon.ParryDrain
		bounce(a)
		FxEvent:FireAllClients(d.state == "block" and "block" or "parry", hitPos, d.player.Name, a.player.Name)
		if d.stamina <= drain then
			d.stamina = 0
			disarm(d)
			return
		end
		spendStamina(d, drain)
		if d.state == "parry" then
			setState(d, "riposte", c.RiposteWindow)
		else
			d.riposteUntil = now() + c.RiposteWindow * TS() -- con escudo también se puede ripostear sin soltar el bloqueo
			d.char:SetAttribute("RiposteUntil", d.riposteUntil)
		end
		setAttr(d)
		return
	end
	-- chamber: el defensor empezó el mismo golpe espejado durante el golpe del atacante
	if d.state == "attack" and d.phase == "windup" and d.kind == a.kind and d.attackStart >= a.attackStart - 0.05
		and now() - d.attackStart <= c.ChamberWindow + a.phaseDur
		and (a.kind == "stab" or Swing.AngleDiff(d.angle, Swing.MirrorAngle(a.angle)) <= c.ChamberAngle)
		and facing(d, a) >= c.ParryCone then
		bounce(a)
		-- chamber: el contragolpe sale rápido, pero todavía se puede fintar (chamber feint) o convertir (chamber morph)
		d.isRiposte = false
		d.chambered = true
		startPhase(d, "windup", c.ChamberCounterWindup)
		FxEvent:FireAllClients("chamber", hitPos, d.player.Name, a.player.Name)
		return
	end
	local zone = zoneOf(hitPart.Name)
	a.hitSomething = true
	applyDamage(a, d, data.Damage * Config.Zones[zone], zone, hitPos)
end

-- el golpe se orienta con la mirada (yaw) que manda el cliente: así girar la cámara acelera o frena la hoja (accel/drag)
local function bodyFrame(f, hrp)
	if f.yaw and now() - (f.lookAt or 0) < 0.5 then
		return CFrame.new(hrp.Position) * CFrame.Angles(0, f.yaw, 0)
	end
	return hrp.CFrame
end

LookEvent.OnServerEvent:Connect(function(player, yaw, pitch)
	local f = fighters[player]
	if not f or type(yaw) ~= "number" or type(pitch) ~= "number" or yaw ~= yaw or pitch ~= pitch then
		return
	end
	local c = Config.Combat
	local t = now()
	-- tope de giro durante carga y golpe (no se puede girar 360 para acelerar)
	if f.yaw and f.state == "attack" and f.phase ~= "recovery" then
		local dt = math.max(t - (f.lookAt or t), 1 / 60)
		local delta = (yaw - f.yaw + math.pi) % (2 * math.pi) - math.pi
		local maxTurn = math.rad(c.TurnCap) * dt * 1.25
		yaw = f.yaw + math.clamp(delta, -maxTurn, maxTurn)
	end
	f.yaw = yaw
	f.lookAt = t
	f.pitch = math.clamp(pitch, -80, 80)
	if f.char and math.abs((f.char:GetAttribute("Pitch") or 0) - f.pitch) >= 2 then
		f.char:SetAttribute("Pitch", math.floor(f.pitch))
	end
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function sweep(f, dt)
	local char = f.char
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local st = { State = "attack", Kind = f.kind, Angle = f.angle, Phase = "release", T = (now() - f.phaseStart) / f.phaseDur }
	local base, tip = Swing.WorldPose(bodyFrame(f, hrp), f.pitch, f.weapon, st)
	local points = Swing.BladePoints(base, tip, 5)
	if f.player:GetAttribute("Debug") then
		FxEvent:FireClient(f.player, "dbgBlade", base, tip)
	end
	local prev = f.prevPoints
	f.prevPoints = points
	f.blade = { base = base, tip = tip, at = now() }
	if not prev or f.hitDone then
		return
	end
	-- dos golpes que se cruzan en el aire: las hojas chocan y ambos rebotan
	for _, other in pairs(fighters) do
		local ob = other.blade
		if other ~= f and not other.dead and other.state == "attack" and other.phase == "release" and not other.hitDone
			and ob and now() - ob.at < 0.1 then
			local dist, point = Swing.SegmentDistance(base:Lerp(tip, 0.3), tip, ob.base:Lerp(ob.tip, 0.3), ob.tip)
			if dist < 0.7 then
				bounce(f)
				bounce(other)
				FxEvent:FireAllClients("weaponclash", point, f.player.Name, other.player.Name)
				return
			end
		end
	end
	rayParams.FilterDescendantsInstances = { char }
	for i = #points, 1, -1 do
		local delta = points[i] - prev[i]
		if delta.Magnitude > 1e-3 then
			local result = workspace:Raycast(prev[i], delta, rayParams)
			if result then
				local other = fighterOfPart(result.Instance)
				if f.player:GetAttribute("Debug") then
					FxEvent:FireClient(f.player, "dbgHit", prev[i], result.Position, other and true or false)
				end
				if other and other ~= f and not other.dead then
					f.hitDone = true
					resolveHit(f, other, result.Instance, result.Position)
					return
				elseif not other and result.Instance:IsDescendantOf(map) and st.T < 0.8 then
					-- la hoja chocó contra el escenario
					FxEvent:FireAllClients("clash", result.Position)
					bounce(f)
					return
				end
			end
		end
	end
end

local function tick(f, dt)
	if f.dead or not f.char or not f.char.Parent then
		return
	end
	local t = now()
	local elapsed = t - f.phaseStart
	-- stamina
	if t - (f.lastSpend or 0) > Config.Stamina.RegenDelay and f.stamina < Config.Stamina.Max then
		f.stamina = math.min(Config.Stamina.Max, f.stamina + Config.Stamina.RegenPerSecond * dt / TS())
	end
	local shown = math.floor(f.stamina + 0.5)
	if f.char:GetAttribute("Stamina") ~= shown then
		f.char:SetAttribute("Stamina", shown)
	end
	if f.state == "attack" then
		if f.phase == "windup" and elapsed >= f.phaseDur then
			startPhase(f, "release", attackData(f).Release)
			f.prevPoints = nil
			sweep(f, dt)
		elseif f.phase == "release" then
			sweep(f, dt)
			if f.state == "attack" and f.phase == "release" and elapsed >= f.phaseDur then
				if not f.hitSomething then
					spendStamina(f, Config.Stamina.Miss)
				end
				local buffered = f.bufferedCombo
				f.bufferedCombo = nil
				local comboed = f.hitSomething and buffered
					and now() - buffered.at <= (Config.Combat.ComboBufferTime + attackData(f).Release) * TS()
					and tryCombo(f, buffered.kind, buffered.angle)
				if not comboed then
					if buffered and not f.hitSomething then
						f.queued = buffered -- golpe al aire: no hay combo, sale al terminar la recuperación
					end
					startPhase(f, "recovery", attackData(f).Recovery)
					f.char:SetAttribute("CanCombo", f.hitSomething)
				end
			end
		elseif f.phase == "recovery" and elapsed >= f.phaseDur then
			local q = f.queued
			f.queued = nil
			toIdle(f)
			if q and now() - q.at <= (Config.Combat.QueueTime + attackData(f).Recovery) * TS() then
				startAttack(f, q.kind, q.angle)
			end
		end
	elseif f.state == "parry" and elapsed >= f.phaseDur then
		setState(f, "parryrec", Config.Combat.ParryRecovery)
	elseif (f.state == "parryrec" or f.state == "riposte" or f.state == "stun" or f.state == "guardbroken" or f.state == "disarmed") and elapsed >= f.phaseDur then
		toIdle(f)
	elseif f.state == "kick" then
		if f.phase == "windup" and elapsed >= f.phaseDur then
			f.phase = "recovery"
			f.phaseStart = t
			f.phaseDur = Config.Combat.KickRecovery * TS()
			setAttr(f)
			-- patada: rompe el bloqueo y saca stamina
			local hrp = f.char.HumanoidRootPart
			for _, other in pairs(fighters) do
				if other ~= f and not other.dead and other.char and other.char:FindFirstChild("HumanoidRootPart") then
					local ohrp = other.char.HumanoidRootPart
					local to = ohrp.Position - hrp.Position
					if to.Magnitude <= Config.Combat.KickRange and hrp.CFrame.LookVector:Dot(to.Unit) > 0.5 then
						FxEvent:FireAllClients("kick", ohrp.Position)
						local guarding = other.state == "parry" or other.state == "block" or other.state == "riposte" or other.state == "parryrec"
						if guarding then
							spendStamina(other, Config.Stamina.KickDrain)
						end
						applyDamage(f, other, 5, "torso", ohrp.Position)
						if not other.dead then
							if guarding then
								setState(other, "guardbroken", Config.Combat.GuardBreakStun)
								FxEvent:FireAllClients("tech", ohrp.Position, f.player.Name, "GUARDIA ROTA")
								FxEvent:FireAllClients("tech", ohrp.Position, other.player.Name, "TE ROMPIERON LA GUARDIA")
							else
								setState(other, "stun", 0.6)
							end
						end
						break
					end
				end
			end
		elseif f.phase == "recovery" and elapsed >= f.phaseDur then
			toIdle(f)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, f in pairs(fighters) do
		tick(f, dt)
	end
end)

-- entradas del cliente
local function canAct(f)
	return f and not f.dead and f.char and f.char.Parent and not f.unarmed and f.state ~= "stun" and f.state ~= "guardbroken"
		and f.state ~= "disarmed"
end

local function handleAction(player, action, a1, a2)
	local f = fighters[player]
	if action == "loadout" then
		if f and type(a1) == "string" then
			f.nextWeapon = Config.Weapon(a1)
			player:SetAttribute("Weapon", f.nextWeapon.Id)
			if f.char and not f.dead and f.state == "idle" then
				f.weapon = f.nextWeapon -- si estás quieto la cambiás en el momento
				setAttr(f)
			end
		end
		return
	end
	if action == "armory" then
		-- abrir la armería al morir congela la reaparición hasta que pida salir
		if f then
			if a1 then
				f.wantSpawn = false -- está eligiendo equipo: no lo saques al campo todavía
			else
				f.wantSpawn = nil
			end
		end
		return
	end
	if action == "spawn" then
		if f and f.dead and now() >= (f.canSpawnAt or 0) then
			f.wantSpawn = nil
			spawnPlayer(player)
		end
		return
	end
	if action == "drop" then
		-- G: si estás sin arma intenta levantar la que tengas cerca; si no, tirás la tuya
		if f and not f.dead and f.char then
			if f.unarmed then
				pickUpWeapon(f)
			elseif f.state ~= "attack" then
				dropWeapon(f, false)
			end
		end
		return
	end
	if action == "gear" then
		-- equipo del caballero: solo estética, se valida contra la lista
		if type(a1) == "string" and type(a2) == "string" and Config.DefaultGear[a1] then
			local opt = Config.GearOption(a1, a2)
			if opt and opt.Id == a2 then
				player:SetAttribute("Gear" .. a1, a2)
				if f and f.char and not f.dead then
					applyLook(player, f.char)
				end
			end
		end
		return
	end
	if action == "style" then
		-- piezas del arma: cada arma guarda las suyas (a1 = "arma:pieza")
		if type(a1) == "string" and type(a2) == "string" then
			local weaponId, key = a1:match("^(%w+):(%w+)$")
			if weaponId and Config.WeaponCustom[weaponId] then
				local opt = Config.WeaponOption(weaponId, key, a2)
				if opt and opt.Id == a2 then
					player:SetAttribute("W" .. weaponId .. "_" .. key, a2)
				end
			end
		end
		return
	end
	if action == "slowmo" then
		-- cámara lenta para practicar: solo el dueño del juego o en Studio (afecta a todo el servidor)
		if RunService:IsStudio() or player.UserId == game.CreatorId then
			matchInfo:SetAttribute("TimeScale", TS() > 1 and 1 or Config.Match.SlowMotion)
			-- movimiento y saltos también en cámara lenta: velocidad / escala, gravedad / escala²
			local scale = TS()
			workspace.Gravity = 196.2 / (scale * scale)
			for _, other in pairs(fighters) do
				if other.hum then
					local base = other.state == "attack" and Config.AttackMoveSpeed or (other.sprint and Config.SprintSpeed or Config.WalkSpeed)
					other.hum.WalkSpeed = base * (other.speedMul or 1) / scale
					other.hum.UseJumpPower = true
					other.hum.JumpPower = 50 / scale
				end
			end
		end
		return
	end
	if action == "debug" then
		player:SetAttribute("Debug", a1 == true)
		return
	end
	if action == "pitch" then
		if f and type(a1) == "number" then
			f.pitch = math.clamp(a1, -80, 80)
			if f.char then
				f.char:SetAttribute("Pitch", math.floor(f.pitch))
			end
		end
		return
	end
	if action == "sprint" then
		if f then
			f.sprint = a1 == true
			if f.hum and f.state == "idle" then
				f.hum.WalkSpeed = speed(f, f.sprint and Config.SprintSpeed or Config.WalkSpeed)
			end
		end
		return
	end
	if not canAct(f) then
		return
	end
	local c = Config.Combat
	local t = now()
	local elapsed = t - f.phaseStart
	if action == "attack" then
		local kind = a1 == "stab" and "stab" or "slash"
		local angle = type(a2) == "number" and math.clamp(a2, -180, 180) or 45
		if f.state == "idle" or f.state == "parryrec" then
			startAttack(f, kind, angle)
		elseif f.state == "riposte" or (f.state == "block" and t <= (f.riposteUntil or 0)) then
			f.riposteUntil = 0
			startAttack(f, kind, angle, c.RiposteWindupScale, { riposte = true })
			FxEvent:FireAllClients("tech", f.char.HumanoidRootPart.Position, f.player.Name, "RIPOSTE")
		elseif f.state == "attack" and f.phase == "windup" and (kind ~= f.kind or Swing.AngleDiff(angle, f.angle) > c.MorphAngle) then
			-- morph: cambiar el golpe manteniendo lo que ya cargaste (también después de un chamber)
			if f.phaseDur - elapsed > c.MorphLockout * TS() and f.stamina >= Config.Stamina.Morph then
				spendStamina(f, Config.Stamina.Morph)
				local frac = math.clamp(elapsed / f.phaseDur, 0, 1)
				local label = f.chambered and "CHAMBER MORPH" or "MORPH"
				f.kind, f.angle = kind, angle
				f.phaseDur = (f.chambered and c.ChamberCounterWindup or attackData(f).Windup) * TS()
				f.phaseStart = t - frac * f.phaseDur
				f.morphed = true
				setAttr(f)
				f.char:SetAttribute("MorphAt", t)
				FxEvent:FireAllClients("tech", f.char.HumanoidRootPart.Position, f.player.Name, label)
			end
		elseif f.state == "attack" and f.phase == "release" then
			-- clic durante el impacto: queda guardado y encadena al terminar
			f.bufferedCombo = { kind = kind, angle = angle, at = t }
		elseif f.state == "attack" and f.phase == "recovery" then
			if f.hitSomething then
				tryCombo(f, kind, angle)
			else
				f.queued = { kind = kind, angle = angle, at = t } -- sin spam: espera a que la mano vuelva
			end
		end
	elseif action == "feint" then
		if f.state == "attack" and f.phase == "windup" and not f.isRiposte and f.phaseDur - elapsed > c.FeintLockout * TS()
			and f.stamina >= Config.Stamina.Feint then
			spendStamina(f, Config.Stamina.Feint)
			local label = f.chambered and "CHAMBER FEINT" or f.morphed and "MORPH FEINT" or "FINTA"
			toIdle(f)
			FxEvent:FireAllClients("feint", f.char.HumanoidRootPart.Position, f.player.Name, label)
		end
	elseif action == "parry" then
		local shield = f.weapon.Kind == "shield"
		local feintable = f.state == "attack" and f.phase == "windup" and not f.isRiposte and f.phaseDur - elapsed > c.FeintLockout * TS()
		if feintable then
			if f.stamina < Config.Stamina.Feint then
				return
			end
			spendStamina(f, Config.Stamina.Feint) -- fintar para parar
			FxEvent:FireAllClients("tech", f.char.HumanoidRootPart.Position, f.player.Name, f.chambered and "CHAMBER FEINT" or "FEINT-TO-PARRY")
		end
		if f.state == "idle" or f.state == "riposte" or feintable or (f.state == "attack" and f.phase == "recovery") then
			if shield then
				setState(f, "block", 9999)
			else
				setState(f, "parry", c.ParryWindow)
			end
			if f.hum then
				f.hum.WalkSpeed = speed(f, Config.AttackMoveSpeed)
			end
		end
	elseif action == "unblock" then
		if f.state == "block" then
			toIdle(f)
		end
	elseif action == "kick" then
		if f.state == "idle" or f.state == "riposte" then
			if f.stamina < Config.Stamina.Kick then
				return
			end
			spendStamina(f, Config.Stamina.Kick)
			f.state = "kick"
			f.kind = nil
			startPhase(f, "windup", c.KickWindup)
		end
	end
end
CombatEvent.OnServerEvent:Connect(handleAction)

---------------------------------------------------------------------------
-- Jugadores, reaparición y partida
---------------------------------------------------------------------------
local function pickSpawn()
	local best, bestScore = spawns[1], -1
	for _, s in ipairs(spawns) do
		local nearest = math.huge
		for _, f in pairs(fighters) do
			local hrp = f.char and f.char:FindFirstChild("HumanoidRootPart")
			if hrp and not f.dead then
				nearest = math.min(nearest, (hrp.Position - s.Position).Magnitude)
			end
		end
		local score = nearest + math.random() * 10
		if score > bestScore then
			best, bestScore = s, score
		end
	end
	return best
end

local function spawnPlayer(player)
	local f = fighters[player]
	if not f or not player.Parent or matchInfo:GetAttribute("Phase") == "intermission" and f.char then
		return
	end
	if f.isBot then
		f.spawnBot()
		return
	end
	if player.Character then
		player.Character:Destroy() -- el cuerpo anterior (LoadCharacter lo hacía solo)
	end
	local char = buildAvatar(player.UserId, player.Name)
	char:PivotTo(pickSpawn())
	player.Character = char
	char.Parent = workspace
end

local tabardIndex = 0

---------------------------------------------------------------------------
-- Personalización: se guarda por jugador y se aplica al caballero
---------------------------------------------------------------------------
local DataStoreService = game:GetService("DataStoreService")
local styleStore
pcall(function()
	styleStore = DataStoreService:GetDataStore("MordoxStyle_v1")
end)

local function styleOf(player)
	local t = { Weapon = player:GetAttribute("Weapon") or Config.Weapons[1].Id, Gear = {}, Weapons = {} }
	for key, default in pairs(Config.DefaultGear) do
		t.Gear[key] = player:GetAttribute("Gear" .. key) or default
	end
	for _, w in ipairs(Config.Weapons) do
		local parts = {}
		for key, default in pairs(Config.DefaultWeaponStyle(w.Id)) do
			parts[key] = player:GetAttribute("W" .. w.Id .. "_" .. key) or default
		end
		t.Weapons[w.Id] = parts
	end
	return t
end

local BOT_GEAR = { Head = "yelmo", Chest = "placas", Legs = "grebas", Armor = "acero", Tabard = "rojo" }

local function applyLook(player, char)
	local f = fighters[player]
	local gear = player:IsA("Player") and styleOf(player).Gear or BOT_GEAR
	Armor.apply(char, gear, false, not player:IsA("Player") and f and f.tabard or nil)
	if f then
		local fx = Armor.effects(gear)
		f.armorMul = { head = fx.head, torso = fx.torso, legs = fx.legs }
		f.speedMul = fx.speed
		if f.hum and not f.dead then
			f.hum.WalkSpeed = speed(f, f.state == "attack" and Config.AttackMoveSpeed or (f.sprint and Config.SprintSpeed or Config.WalkSpeed))
		end
	end
end

local function loadStyle(player)
	if not styleStore then
		return
	end
	local ok, saved = pcall(function()
		return styleStore:GetAsync("p" .. player.UserId)
	end)
	if ok and type(saved) == "table" then
		for key in pairs(Config.DefaultGear) do
			local id = saved.Gear and saved.Gear[key]
			if type(id) == "string" and Config.GearOption(key, id).Id == id then
				player:SetAttribute("Gear" .. key, id)
			end
		end
		for _, w in ipairs(Config.Weapons) do
			local parts = saved.Weapons and saved.Weapons[w.Id]
			for key in pairs(Config.DefaultWeaponStyle(w.Id)) do
				local id = parts and parts[key]
				if type(id) == "string" and Config.WeaponOption(w.Id, key, id).Id == id then
					player:SetAttribute("W" .. w.Id .. "_" .. key, id)
				end
			end
		end
		if type(saved.Weapon) == "string" and Config.Weapon(saved.Weapon).Id == saved.Weapon then
			player:SetAttribute("Weapon", saved.Weapon)
			local f = fighters[player]
			if f then
				f.nextWeapon = Config.Weapon(saved.Weapon)
			end
		end
	end
end

local function saveStyle(player)
	if not styleStore then
		return
	end
	pcall(function()
		styleStore:SetAsync("p" .. player.UserId, styleOf(player))
	end)
end

local function onCharacter(player, char)
	local f = fighters[player]
	f.char = char
	fighterByChar[char] = f
	f.hum = char:WaitForChild("Humanoid")
	f.dead = false
	f.weapon = f.nextWeapon or f.weapon
	f.unarmed = false
	char:SetAttribute("Unarmed", false)
	f.stamina = Config.Stamina.Max
	f.hum.UseJumpPower = true
	f.hum.JumpPower = 50 / TS()
	f.pitch = 0
	f.sprint = false
	char:WaitForChild("HumanoidRootPart")
	if not char:IsDescendantOf(workspace) then
		char.AncestryChanged:Wait()
	end
	char:PivotTo(pickSpawn())
	applyLook(player, char)
	toIdle(f)
	f.hum.Died:Connect(function()
		if not f.dead then
			killed(f, f.lastHitBy, f.lastHitBy and f.lastHitBy.weapon.Name)
		end
		f.canSpawnAt = now() + Config.Match.RespawnTime
		char:SetAttribute("CanSpawnAt", f.canSpawnAt)
		task.delay(Config.Match.RespawnTime, function()
			-- en la armería: si pidió salir al campo, aparece; si no, espera ahí
			if player.Parent and f.char == char and f.wantSpawn ~= false then
				spawnPlayer(player)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	tabardIndex += 1
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats
	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Parent = stats
	stats.Parent = player
	fighters[player] = {
		player = player, state = "idle", stamina = Config.Stamina.Max, weapon = Config.Weapons[1],
		tabard = Config.Tabards[(tabardIndex - 1) % #Config.Tabards + 1], phaseStart = 0, phaseDur = 0, pitch = 0,
	}
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	player:SetAttribute("Weapon", Config.Weapons[1].Id)
	for key, default in pairs(Config.DefaultGear) do
		player:SetAttribute("Gear" .. key, default)
	end
	for _, w in ipairs(Config.Weapons) do
		for key, default in pairs(Config.DefaultWeaponStyle(w.Id)) do
			player:SetAttribute("W" .. w.Id .. "_" .. key, default)
		end
	end
	loadStyle(player) -- lo que haya elegido la última vez
	task.spawn(publishPreview, player)
	spawnPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveStyle(player)
	fighters[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveStyle(player)
	end
end)

---------------------------------------------------------------------------
-- Caballeros de práctica (bots): usan las mismas acciones que un jugador
---------------------------------------------------------------------------
local botFolder = Instance.new("Folder")
botFolder.Name = "MordoxBots"
botFolder.Parent = workspace
local botPlayers = Instance.new("Folder")
botPlayers.Name = "MordoxBotPlayers"
botPlayers.Parent = game:GetService("ServerStorage")
local botRng = Random.new()
local PathfindingService = game:GetService("PathfindingService")

-- camino alrededor de paredes y cajas hacia el rival (se recalcula cada medio segundo)
local function botWalk(f, hrp, goal)
	local t = now()
	if not f.path or t - f.pathAt > 0.5 or (f.pathGoal - goal).Magnitude > 4 then
		f.pathAt, f.pathGoal = t, goal
		local path = PathfindingService:CreatePath({ AgentRadius = 2.2, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 4 })
		local ok = pcall(function()
			path:ComputeAsync(hrp.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			f.path, f.pathIndex = path:GetWaypoints(), 2
		else
			f.path, f.pathIndex = nil, nil
		end
	end
	local wp = f.path and f.path[f.pathIndex]
	while wp and ((wp.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 and f.pathIndex < #f.path do
		f.pathIndex += 1
		wp = f.path[f.pathIndex]
	end
	f.hum:MoveTo(wp and wp.Position or goal)
	-- trabado contra algo: saltar
	if f.lastPos and (hrp.Position - f.lastPos).Magnitude < 0.15 then
		f.stuck = (f.stuck or 0) + 1
		if f.stuck > 8 then
			f.hum.Jump = true
			f.stuck = 0
			f.path = nil
		end
	else
		f.stuck = 0
	end
	f.lastPos = hrp.Position
end

local function nearestEnemy(f)
	local hrp = f.char and f.char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, other in pairs(fighters) do
		local ohrp = other ~= f and not other.dead and other.char and other.char:FindFirstChild("HumanoidRootPart")
		if ohrp then
			local d = (ohrp.Position - hrp.Position).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best, bestDist
end

local ANGLES = { -135, -90, -45, 0, 45, 90, 135 }

local function botThink(f)
	if f.dead or not f.char or not f.hum or f.hum.Health <= 0 then
		return
	end
	local hrp = f.char:FindFirstChild("HumanoidRootPart")
	local target, dist = nearestEnemy(f)
	if not target or not hrp then
		f.hum:Move(Vector3.zero)
		return
	end
	local t = now()
	local thrp = target.char.HumanoidRootPart
	local flat = (thrp.Position - hrp.Position) * Vector3.new(1, 0, 1)
	local dir = flat.Magnitude > 0.1 and flat.Unit or hrp.CFrame.LookVector
	-- moverse hasta quedar a distancia de espada y mirar al rival
	if not Config.Match.BotsMove then
		-- dummy quieto: solo gira hacia el rival cercano
		f.hum.AutoRotate = false
		f.hum:Move(Vector3.zero)
		if dist < 14 then
			local yaw = math.atan2(-dir.X, -dir.Z)
			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
			f.yaw, f.lookAt = yaw, t
		end
	elseif dist > 5.2 then
		f.hum.AutoRotate = true
		botWalk(f, hrp, thrp.Position - dir * 4)
	else
		f.hum.AutoRotate = false
		f.hum:Move(dist < 3 and -dir or Vector3.zero)
		local yaw = math.atan2(-dir.X, -dir.Z)
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
		f.yaw, f.lookAt = yaw, t
	end
	local player = f.player
	-- defensa: intentar parar cuando el golpe del rival está por salir
	if target.state == "attack" and target.phase == "windup" and target.attackStart ~= f.readAttack and dist < 7 then
		local remaining = target.phaseDur - (t - target.phaseStart)
		if remaining < 0.22 * TS() then
			f.readAttack = target.attackStart
			if botRng:NextNumber() < 0.55 then
				handleAction(player, "parry")
				return
			end
		end
	end
	if dist > 6.5 then
		return
	end
	-- ataque: riposte enseguida, combo a veces, patada si el rival se cubre
	if f.state == "riposte" then
		handleAction(player, "attack", botRng:NextNumber() < 0.3 and "stab" or "slash", ANGLES[botRng:NextInteger(1, #ANGLES)])
	elseif f.state == "attack" and f.phase == "recovery" and f.attackStart ~= f.comboTried then
		f.comboTried = f.attackStart
		if botRng:NextNumber() < 0.35 then
			handleAction(player, "attack", "slash", ANGLES[botRng:NextInteger(1, #ANGLES)])
		end
	elseif f.state == "idle" and t >= (f.nextAttack or 0) then
		f.nextAttack = t + botRng:NextNumber(0.8, 1.9)
		if target.state == "block" and botRng:NextNumber() < 0.5 then
			handleAction(player, "kick")
		else
			handleAction(player, "attack", botRng:NextNumber() < 0.25 and "stab" or "slash", ANGLES[botRng:NextInteger(1, #ANGLES)])
		end
	end
end

for i = 1, Config.Match.Bots or 0 do
	local botPlayer = Instance.new("Folder")
	botPlayer.Name = "Dummy" .. (i > 1 and i or "")
	botPlayer.Parent = botPlayers
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, n in ipairs({ "Kills", "Deaths" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = stats
	end
	stats.Parent = botPlayer
	tabardIndex += 1
	local f = {
		player = botPlayer, isBot = true, state = "idle", stamina = Config.Stamina.Max,
		weapon = Config.Weapons[(i - 1) % #Config.Weapons + 1], tabard = Config.Tabards[(tabardIndex - 1) % #Config.Tabards + 1],
		phaseStart = 0, phaseDur = 0, pitch = 0,
	}
	fighters[botPlayer] = f
	f.spawnBot = function()
		if f.char then
			f.char:Destroy()
		end
		local char = buildAvatar(0, botPlayer.Name)
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Decal") then
				d:Destroy() -- el dummy no tiene cara
			end
		end
		char.Name = botPlayer.Name
		char.Parent = botFolder
		task.spawn(function()
			onCharacter(botPlayer, char)
			-- barra de vida sobre la cabeza del dummy
			local head = char:FindFirstChild("Head")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if head and hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				local gui = Instance.new("BillboardGui")
				gui.Name = "DummyBar"
				gui.Size = UDim2.new(4, 0, 0.9, 0)
				gui.StudsOffset = Vector3.new(0, 2.4, 0)
				gui.AlwaysOnTop = true
				gui.Parent = head
				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(1, 0, 0.5, 0)
				name.BackgroundTransparency = 1
				name.Text = "DUMMY"
				name.Font = Enum.Font.GothamBlack
				name.TextScaled = true
				name.TextColor3 = Color3.new(1, 1, 1)
				name.TextStrokeTransparency = 0.3
				name.Parent = gui
				local back = Instance.new("Frame")
				back.Position = UDim2.new(0, 0, 0.6, 0)
				back.Size = UDim2.new(1, 0, 0.35, 0)
				back.BackgroundColor3 = Color3.fromRGB(25, 20, 20)
				back.Parent = gui
				local fill = Instance.new("Frame")
				fill.Size = UDim2.fromScale(1, 1)
				fill.BackgroundColor3 = Color3.fromRGB(200, 45, 40)
				fill.BorderSizePixel = 0
				fill.Parent = back
				hum.HealthChanged:Connect(function(hp)
					fill.Size = UDim2.fromScale(math.clamp(hp / hum.MaxHealth, 0, 1), 1)
				end)
			end
			if not Config.Match.BotsMove then
				char:PivotTo(CFrame.lookAt(Vector3.new(8 * i, 3.5, 30), Vector3.new(8 * i, 3.5, 60)))
			end
		end)
		task.defer(function()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsDescendantOf(workspace) then
				pcall(function()
					hrp:SetNetworkOwner(nil)
				end)
			end
		end)
	end
	f.spawnBot()
end

task.spawn(function()
	while true do
		task.wait(0.1)
		for _, f in pairs(fighters) do
			if f.isBot then
				local ok, err = pcall(botThink, f)
				if not ok then
					warn("bot:", err)
				end
			end
		end
	end
end)

-- ciclo de partida
task.spawn(function()
	while true do
		matchInfo:SetAttribute("Phase", "playing")
		matchInfo:SetAttribute("Winner", "")
		matchInfo:SetAttribute("EndsAt", now() + Config.Match.Duration)
		for _, p in ipairs(Players:GetPlayers()) do
			local s = p:FindFirstChild("leaderstats")
			if s then
				s.Kills.Value, s.Deaths.Value = 0, 0
			end
			if p.Character then
				spawnPlayer(p)
			end
		end
		local winner
		while now() < matchInfo:GetAttribute("EndsAt") do
			task.wait(0.5)
			for _, p in ipairs(Players:GetPlayers()) do
				local s = p:FindFirstChild("leaderstats")
				if s and s.Kills.Value >= Config.Match.KillLimit then
					winner = p
				end
			end
			if winner then
				break
			end
		end
		if not winner then
			local best = -1
			for _, p in ipairs(Players:GetPlayers()) do
				local s = p:FindFirstChild("leaderstats")
				if s and s.Kills.Value > best then
					winner, best = p, s.Kills.Value
				end
			end
		end
		matchInfo:SetAttribute("Winner", winner and winner.Name or "")
		matchInfo:SetAttribute("Phase", "intermission")
		matchInfo:SetAttribute("EndsAt", now() + Config.Match.IntermissionTime)
		task.wait(Config.Match.IntermissionTime)
	end
end)
