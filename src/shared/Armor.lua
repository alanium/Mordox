-- MordoxArmor (ModuleScript en ReplicatedStorage)
-- Arma las piezas de armadura encima del avatar del jugador (cabeza, torso y piernas).
-- Lo usa el servidor sobre el personaje real (piezas soldadas) y el cliente sobre la vista previa de la armería (piezas ancladas).
-- Las piezas miden en proporción a cada parte del cuerpo, así calzan en cualquier avatar R15.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MordoxConfig"))

local Armor = {}

local CHAIN = Color3.fromRGB(118, 121, 128)
local LEATHER = Color3.fromRGB(70, 45, 25)
local PADDING = Color3.fromRGB(96, 72, 48)
local SLIT = Color3.new(0.04, 0.04, 0.04)

local function darker(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- una pieza pegada a una parte del cuerpo: tamaño y posición en proporción a esa parte
local function piece(folder, host, name, sizeMul, offsetMul, color, material, rot, anchored)
	if not host then
		return nil
	end
	local s = host.Size
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(s.X * sizeMul.X, s.Y * sizeMul.Y, s.Z * sizeMul.Z)
	p.CFrame = host.CFrame * CFrame.new(s.X * offsetMul.X, s.Y * offsetMul.Y, s.Z * offsetMul.Z) * (rot or CFrame.identity)
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false -- los golpes pegan en el cuerpo de abajo: así la zona (cabeza, torso, piernas) sale del cuerpo
	p.CanTouch = false
	p.Massless = true
	if anchored then
		p.Anchored = true
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = folder
	return p
end

local V = Vector3.new

-- gear: ids elegidos (Head, Chest, Legs, Armor, Tabard); tabardColor opcional pisa el color del tabardo (bots)
function Armor.apply(char, gear, anchored, tabardColor)
	local old = char:FindFirstChild("MordoxArmor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MordoxArmor"
	folder.Parent = char

	local metalOpt = Config.GearOption("Armor", gear.Armor)
	local metal, dark = metalOpt.Color, metalOpt.Dark
	local tabard = tabardColor or Config.GearOption("Tabard", gear.Tabard).Color
	local head = Config.GearOption("Head", gear.Head).Tier
	local chest = Config.GearOption("Chest", gear.Chest).Tier
	local legs = Config.GearOption("Legs", gear.Legs).Tier

	local function part(name)
		return char:FindFirstChild(name)
	end
	local function add(name, host, size, offset, color, material, rot)
		return piece(folder, part(host), name, size, offset, color, material, rot, anchored)
	end

	-- cabeza: con cualquier protección se esconden pelo y sombreros del avatar
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
			local onHead = weld and (weld.Part0 == part("Head") or weld.Part1 == part("Head"))
			if handle then
				handle.CanQuery = false
				handle.Transparency = (onHead and head >= 1) and 1 or 0
			end
		end
	end
	if head >= 1 then
		-- cofia de malla: deja la cara al aire
		add("ArmorCoif", "Head", V(1.2, 1.12, 1.06), V(0, 0.07, 0.12), CHAIN, Enum.Material.DiamondPlate)
		add("ArmorCollar", "UpperTorso", V(0.62, 0.16, 0.9), V(0, 0.52, 0), CHAIN, Enum.Material.DiamondPlate)
	end
	if head == 2 then
		-- bacinete abierto: casquete y nuca de acero, la cara se sigue viendo
		add("ArmorSkull", "Head", V(1.24, 0.6, 1.2), V(0, 0.34, 0.04), metal)
		add("ArmorNape", "Head", V(1.24, 0.72, 0.5), V(0, -0.02, 0.38), metal)
		add("ArmorBrow", "Head", V(1.26, 0.12, 0.2), V(0, 0.08, -0.5), dark)
	elseif head == 3 then
		-- yelmo cerrado con ranura para ver y cresta del color del tabardo
		add("ArmorHelm", "Head", V(1.26, 1.24, 1.26), V(0, 0.05, 0), metal)
		add("ArmorSlit", "Head", V(0.92, 0.07, 0.06), V(0, 0.12, -0.64), SLIT, Enum.Material.SmoothPlastic)
		add("ArmorCrest", "Head", V(0.14, 0.3, 0.95), V(0, 0.76, 0), tabard, Enum.Material.Fabric)
	end

	-- torso
	if chest == 1 then
		-- gambesón acolchado del color del tabardo
		add("ArmorGambeson", "UpperTorso", V(1.1, 1.06, 1.18), V(0, 0, 0), tabard, Enum.Material.Fabric)
		add("ArmorGambesonSkirt", "LowerTorso", V(1.1, 1.9, 1.16), V(0, -0.35, 0), tabard, Enum.Material.Fabric)
		for _, side in ipairs({ "Left", "Right" }) do
			add("ArmorSleeve", side .. "UpperArm", V(1.14, 1.02, 1.14), V(0, 0, 0), darker(tabard, 0.85), Enum.Material.Fabric)
		end
	elseif chest >= 2 then
		-- cota de malla con faldón, y el tabardo encima
		add("ArmorMail", "UpperTorso", V(1.1, 1.05, 1.16), V(0, 0, 0), CHAIN, Enum.Material.DiamondPlate)
		add("ArmorMailSkirt", "LowerTorso", V(1.1, 2.1, 1.14), V(0, -0.45, 0), CHAIN, Enum.Material.DiamondPlate)
		for _, side in ipairs({ "Left", "Right" }) do
			add("ArmorMailSleeve", side .. "UpperArm", V(1.12, 1.02, 1.12), V(0, 0, 0), CHAIN, Enum.Material.DiamondPlate)
		end
		if chest == 3 then
			-- placas: peto, hombreras, brazales y guanteletes
			add("ArmorBreastplate", "UpperTorso", V(1.16, 1.02, 1.22), V(0, 0.02, 0), metal)
			for _, side in ipairs({ "Left", "Right" }) do
				add("ArmorPauldron", side .. "UpperArm", V(1.6, 0.42, 1.5), V(0, 0.4, 0), metal)
				add("ArmorVambrace", side .. "LowerArm", V(1.1, 0.85, 1.1), V(0, 0.04, 0), metal)
				add("ArmorGauntlet", side .. "Hand", V(1.1, 1.05, 1.1), V(0, 0, 0), dark)
			end
		end
		local ut = part("UpperTorso")
		local depth = chest == 3 and 0.63 or 0.6
		add("ArmorTabard", "UpperTorso", V(0.62, 1.55, 0.05), V(0, -0.3, -depth), tabard, Enum.Material.Fabric)
		add("ArmorTabardBack", "UpperTorso", V(0.62, 1.45, 0.05), V(0, -0.32, depth), tabard, Enum.Material.Fabric)
		if ut then
			add("ArmorBelt", "LowerTorso", V(1.16, 0.5, 1.2), V(0, 0.15, 0), LEATHER, Enum.Material.Leather)
		end
	end

	-- piernas
	for _, side in ipairs({ "Left", "Right" }) do
		if legs == 1 then
			add("ArmorHose", side .. "UpperLeg", V(1.1, 1.0, 1.1), V(0, 0, 0), PADDING, Enum.Material.Fabric)
			add("ArmorHoseLow", side .. "LowerLeg", V(1.08, 1.0, 1.08), V(0, 0, 0), PADDING, Enum.Material.Fabric)
		elseif legs >= 2 then
			add("ArmorChausses", side .. "UpperLeg", V(1.1, 1.0, 1.1), V(0, 0, 0), CHAIN, Enum.Material.DiamondPlate)
			add("ArmorChaussesLow", side .. "LowerLeg", V(1.08, 1.0, 1.08), V(0, 0, 0), CHAIN, Enum.Material.DiamondPlate)
			if legs == 3 then
				add("ArmorCuisse", side .. "UpperLeg", V(1.16, 0.8, 1.18), V(0, 0.08, -0.02), metal)
				add("ArmorKnee", side .. "LowerLeg", V(1.2, 0.3, 1.2), V(0, 0.45, -0.08), dark)
				add("ArmorGreave", side .. "LowerLeg", V(1.12, 0.85, 1.14), V(0, -0.05, 0), metal)
				add("ArmorSabaton", side .. "Foot", V(1.08, 1.2, 1.06), V(0, 0.05, 0), dark)
			end
		end
	end

	char:SetAttribute("Tabard", tabard)
	return folder
end

-- protección y peso: cuánto daño pasa en cada zona y qué tan rápido te movés
function Armor.effects(gear)
	local head = Config.GearOption("Head", gear.Head).Tier
	local chest = Config.GearOption("Chest", gear.Chest).Tier
	local legs = Config.GearOption("Legs", gear.Legs).Tier
	local cut = Config.ArmorTier
	local weight = Config.ArmorWeight
	return {
		head = cut[head].Damage,
		torso = cut[chest].Damage,
		legs = cut[legs].Damage,
		speed = 1 - head * weight.Head - chest * weight.Chest - legs * weight.Legs,
	}
end

return Armor
