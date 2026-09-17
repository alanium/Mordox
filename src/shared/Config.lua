-- MordoxConfig (ModuleScript en ReplicatedStorage)
-- Datos compartidos: armas, tiempos de combate, stamina, daño y partida.

local Config = {}

-- Partida (todos contra todos)
Config.Match = {
	Duration = 600, -- segundos por partida
	KillLimit = 30, -- el primero en llegar gana
	RespawnTime = 4,
	IntermissionTime = 12,
	Bots = 1, -- caballeros de práctica controlados por el servidor (0 = ninguno)
	BotsDealDamage = false, -- el dummy pega (stun, chispas) pero no te saca vida
	BotsImmortal = true, -- al dummy le baja la vida, pero al llegar a 0 se recarga en vez de morir
	SlowMotion = 4, -- cámara lenta (F4): todo el combate dura 4 veces más
	BotsMove = false, -- false = el dummy se queda quieto en su lugar, pero pega, para y ripostea
}

Config.MaxHealth = 100
Config.WalkSpeed = 15
Config.SprintSpeed = 21
Config.AttackMoveSpeed = 11 -- velocidad mientras cargás o golpeás

-- Stamina
Config.Stamina = {
	Max = 100,
	RegenPerSecond = 14,
	RegenDelay = 1.2, -- segundos sin gastar antes de recuperar
	Feint = 12,
	Morph = 10,
	Miss = 4, -- golpe que no toca a nadie
	Kick = 12,
	Combo = 6, -- costo extra por encadenar un golpe
	ComboStep = 3, -- cada golpe más de la cadena cuesta esto más
	ComboMin = 8, -- stamina mínima para poder encadenar
	KickDrain = 18, -- lo que le saca una patada al que para
	DisarmTime = 1.6, -- quedarse sin stamina bloqueando = te desarman
}

-- Combate (segundos)
Config.Combat = {
	ParryWindow = 0.3, -- bloqueo activo
	ParryRecovery = 0.35, -- no podés volver a parar enseguida si fallaste
	RiposteWindow = 0.45, -- después de un parry exitoso
	RiposteWindupScale = 0.55,
	FeintLockout = 0.12, -- los últimos segundos de la carga no se pueden fintar
	MorphLockout = 0.1,
	ChamberWindow = 0.25, -- iniciar el mismo golpe espejado dentro de esta ventana
	ChamberAngle = 45,
	ChamberCounterWindup = 0.4, -- carga del contragolpe tras un chamber (deja margen para chamber feint y chamber morph)
	MorphAngle = 30, -- cambiar de dirección más que esto dentro del mismo tipo también es morph
	HitStun = 0.35, -- flinch al recibir daño
	ParryCone = 0.25, -- producto punto mínimo: el atacante tiene que estar adelante
	ShieldCone = -0.1,
	KickRange = 4.5,
	KickWindup = 0.35,
	KickRecovery = 0.5,
	BounceRecovery = 0.55, -- golpe contra pared o parado
	ComboWindupScale = 0.8, -- carga más corta al encadenar
	ComboBufferTime = 0.35,
	QueueTime = 0.5, -- clic antes de que termine la recuperación: el golpe sale apenas la mano vuelve a la guardia
	GuardBreakStun = 1.0, -- patada contra alguien que se cubre: guardia rota -- clic durante el golpe: se guarda y encadena apenas termina el impacto
	ArmReach = 1.4, -- distancia del pecho a las manos
	AttackSensitivity = 0.55, -- el mouse se mueve más lento mientras cargás y golpeás
	TurnCap = 540, -- grados por segundo máximo de giro durante el golpe (drag/accel)
}

-- Multiplicadores de daño por zona
Config.Zones = { head = 1.35, torso = 1, legs = 0.8 }

-- Armas
-- Kind: "twohand" (dos manos), "onehand" (una mano, la otra libre), "shield" (una mano + escudo)
-- Slash/Stab: tiempos (Windup, Release, Recovery) y daño base; Length = largo de la hoja desde las manos
Config.Weapons = {
	{
		Id = "espadon", Name = "Espadón", Kind = "twohand", Length = 3.9, Grip = 1.3,
		Slash = { Windup = 0.62, Release = 0.40, Recovery = 0.50, Damage = 50, Type = "cut" },
		Stab = { Windup = 0.66, Release = 0.34, Recovery = 0.52, Damage = 54, Type = "pierce" },
		ParryDrain = 18, Color = Color3.fromRGB(205, 210, 220),
	},
	{
		-- más lento y más pesado que el espadón, con el mayor alcance
		Id = "mandoble", Name = "Mandoble", Kind = "twohand", Length = 4.7, Grip = 1.7, Ricasso = true,
		Slash = { Windup = 0.88, Release = 0.46, Recovery = 0.68, Damage = 70, Type = "cut" },
		Stab = { Windup = 0.92, Release = 0.40, Recovery = 0.70, Damage = 72, Type = "pierce" },
		ParryDrain = 26, Color = Color3.fromRGB(198, 202, 212),
	},
}

-- Personalización (solo estética: no cambia daño, alcance ni tiempos)
-- Cada categoría tiene opciones con los datos que el cliente usa para dibujarlas.
Config.Custom = {
	{ Key = "Blade", Name = "Hoja", Options = {
		{ Id = "recta", Name = "Recta", Width = 0.26, Thick = 0.075, Tip = 0.5, Fuller = true },
		{ Id = "ancha", Name = "Ancha", Width = 0.36, Thick = 0.085, Tip = 0.7 },
		{ Id = "estoque", Name = "De estoque", Width = 0.17, Thick = 0.1, Tip = 0.25 },
		{ Id = "flamigera", Name = "Flamígera", Width = 0.28, Thick = 0.075, Tip = 0.55, Wave = true },
	} },
	{ Key = "Guard", Name = "Guarda", Options = {
		{ Id = "cruz", Name = "Cruz recta", Span = 0.95, Style = "recta" },
		{ Id = "curva", Name = "Curva", Span = 1.05, Style = "curva" },
		{ Id = "anillos", Name = "Con anillos", Span = 0.85, Style = "anillos" },
		{ Id = "ese", Name = "En ese", Span = 1.1, Style = "ese" },
	} },
	{ Key = "Grip", Name = "Empuñadura", Options = {
		{ Id = "cuero", Name = "Cuero", Color = Color3.fromRGB(60, 40, 25), Material = "Leather" },
		{ Id = "cuerda", Name = "Cuerda", Color = Color3.fromRGB(150, 130, 95), Material = "Fabric", Rings = true },
		{ Id = "alambre", Name = "Alambre", Color = Color3.fromRGB(120, 105, 70), Material = "Metal", Rings = true },
		{ Id = "madera", Name = "Madera", Color = Color3.fromRGB(95, 62, 38), Material = "Wood" },
	} },
	{ Key = "Pommel", Name = "Pomo", Options = {
		{ Id = "disco", Name = "Disco", Shape = "disco" },
		{ Id = "bola", Name = "Bola", Shape = "bola" },
		{ Id = "pera", Name = "Pera", Shape = "pera" },
		{ Id = "escudete", Name = "Escudete", Shape = "escudete" },
	} },
	{ Key = "Metal", Name = "Metal del arma", Options = {
		{ Id = "acero", Name = "Acero", Color = Color3.fromRGB(205, 210, 220), Dark = Color3.fromRGB(80, 80, 88) },
		{ Id = "oscuro", Name = "Acero oscuro", Color = Color3.fromRGB(120, 124, 132), Dark = Color3.fromRGB(45, 45, 52) },
		{ Id = "bronce", Name = "Bronce", Color = Color3.fromRGB(196, 150, 78), Dark = Color3.fromRGB(110, 78, 34) },
		{ Id = "blanco", Name = "Plata pulida", Color = Color3.fromRGB(240, 242, 248), Dark = Color3.fromRGB(150, 152, 160) },
	} },
	{ Key = "Helmet", Name = "Casco", Options = {
		{ Id = "yelmo", Name = "Yelmo con cresta" },
		{ Id = "bacinete", Name = "Bacinete" },
		{ Id = "capucha", Name = "Capucha de malla" },
		{ Id = "sin", Name = "Sin casco" },
	} },
	{ Key = "Armor", Name = "Color de armadura", Options = {
		{ Id = "acero", Name = "Acero", Color = Color3.fromRGB(165, 170, 180), Dark = Color3.fromRGB(95, 98, 105) },
		{ Id = "oscuro", Name = "Oscura", Color = Color3.fromRGB(95, 98, 108), Dark = Color3.fromRGB(55, 57, 64) },
		{ Id = "bronce", Name = "Bronce", Color = Color3.fromRGB(180, 138, 72), Dark = Color3.fromRGB(105, 74, 32) },
		{ Id = "negra", Name = "Negra", Color = Color3.fromRGB(58, 58, 62), Dark = Color3.fromRGB(32, 32, 36) },
	} },
	{ Key = "Tabard", Name = "Tabardo", Options = {
		{ Id = "rojo", Name = "Rojo", Color = Color3.fromRGB(170, 35, 35) },
		{ Id = "azul", Name = "Azul", Color = Color3.fromRGB(35, 70, 160) },
		{ Id = "verde", Name = "Verde", Color = Color3.fromRGB(40, 120, 55) },
		{ Id = "dorado", Name = "Dorado", Color = Color3.fromRGB(190, 150, 30) },
		{ Id = "violeta", Name = "Violeta", Color = Color3.fromRGB(110, 40, 140) },
		{ Id = "negro", Name = "Negro", Color = Color3.fromRGB(60, 60, 60) },
	} },
}

Config.DefaultStyle = {
	Blade = "recta", Guard = "cruz", Grip = "cuero", Pommel = "disco",
	Metal = "acero", Helmet = "yelmo", Armor = "acero", Tabard = "rojo",
}

-- Devuelve la opción elegida (o la primera si el id no existe)
function Config.StyleOption(key, id)
	for _, cat in ipairs(Config.Custom) do
		if cat.Key == key then
			for _, opt in ipairs(cat.Options) do
				if opt.Id == id then
					return opt
				end
			end
			return cat.Options[1]
		end
	end
	return nil
end

function Config.Weapon(id)
	for _, w in ipairs(Config.Weapons) do
		if w.Id == id then
			return w
		end
	end
	return Config.Weapons[1]
end

-- Colores de tabardo para distinguir jugadores en el todos contra todos
Config.Tabards = {
	Color3.fromRGB(170, 35, 35), Color3.fromRGB(35, 70, 160), Color3.fromRGB(40, 120, 55), Color3.fromRGB(190, 150, 30),
	Color3.fromRGB(110, 40, 140), Color3.fromRGB(30, 130, 140), Color3.fromRGB(200, 90, 30), Color3.fromRGB(60, 60, 60),
}

return Config
