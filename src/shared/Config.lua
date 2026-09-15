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
	ComboBufferTime = 0.35, -- clic durante el golpe: se guarda y encadena apenas termina el impacto
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
		Id = "longsword", Name = "Espada larga", Kind = "twohand", Length = 3.6, Grip = 1.0,
		Slash = { Windup = 0.59, Release = 0.38, Recovery = 0.47, Damage = 46, Type = "cut" },
		Stab = { Windup = 0.63, Release = 0.33, Recovery = 0.50, Damage = 52, Type = "pierce" },
		ParryDrain = 16, Color = Color3.fromRGB(205, 210, 220),
	},
	{
		Id = "greataxe", Name = "Hacha de guerra", Kind = "twohand", Length = 3.4, Grip = 1.2,
		Slash = { Windup = 0.77, Release = 0.43, Recovery = 0.62, Damage = 64, Type = "cut" },
		Stab = { Windup = 0.70, Release = 0.35, Recovery = 0.56, Damage = 38, Type = "blunt" },
		ParryDrain = 26, Color = Color3.fromRGB(150, 150, 160),
	},
	{
		Id = "mace", Name = "Maza", Kind = "onehand", Length = 2.4, Grip = 0.4,
		Slash = { Windup = 0.53, Release = 0.35, Recovery = 0.40, Damage = 40, Type = "blunt" },
		Stab = { Windup = 0.59, Release = 0.30, Recovery = 0.45, Damage = 26, Type = "blunt" },
		ParryDrain = 20, Color = Color3.fromRGB(120, 120, 130),
	},
	{
		Id = "swordshield", Name = "Espada y escudo", Kind = "shield", Length = 2.6, Grip = 0.4,
		Slash = { Windup = 0.50, Release = 0.34, Recovery = 0.40, Damage = 34, Type = "cut" },
		Stab = { Windup = 0.53, Release = 0.30, Recovery = 0.43, Damage = 38, Type = "pierce" },
		ParryDrain = 12, ShieldDrainPerHit = 10, Color = Color3.fromRGB(215, 215, 225),
	},
}

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
