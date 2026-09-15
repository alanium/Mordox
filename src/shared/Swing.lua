-- Swing (ModuleScript en ReplicatedStorage)
-- Geometría de cada golpe en función del tiempo. El servidor la usa para detectar impactos y el cliente para dibujar
-- brazos y arma, así lo que se ve es exactamente lo que pega.
--
-- Espacio local del cuerpo: X derecha, Y arriba, -Z adelante; origen en el HumanoidRootPart.
-- angle (grados): de dónde viene el corte visto desde el atacante. 0 = de arriba, 90 = de la derecha,
-- -90 = de la izquierda, 180 = de abajo.

local Config = require(script.Parent:WaitForChild("MordoxConfig"))

local Swing = {}

local PIVOT = Vector3.new(0, 0.95, -0.25) -- pecho
local FORWARD = Vector3.new(0, 0, -1)
local rad = math.rad

local function slerpDir(a, b, k)
	local dot = math.clamp(a:Dot(b), -1, 1)
	local theta = math.acos(dot)
	if theta < 1e-3 then
		return a
	end
	local s = math.sin(theta)
	return (a * math.sin((1 - k) * theta) + b * math.sin(k * theta)) / s
end

local function ease(k)
	return k * k * (3 - 2 * k)
end

-- dirección del arma para un corte que viene del lado "angle", avanzando alpha grados desde ese lado hacia adelante
function Swing.SlashDir(angle, alpha)
	local side = Vector3.new(math.sin(rad(angle)), math.cos(rad(angle)), 0)
	local a = rad(alpha)
	return (side * math.cos(a) + FORWARD * math.sin(a)).Unit
end

function Swing.GuardDir(weapon)
	if weapon.Kind == "twohand" then
		return Vector3.new(0.25, 0.65, -0.72).Unit
	end
	return Vector3.new(0.15, 0.55, -0.82).Unit
end

-- Torso y cabeza como un cilindro elíptico: las manos lo rodean por delante en vez de atravesarlo
local BODY = { halfX = 1.2, halfZ = 0.8, bottom = -1.4, top = 1.9 }

function Swing.ClearBody(p)
	if p.Y < BODY.bottom or p.Y > BODY.top then
		return p
	end
	local nx, nz = p.X / BODY.halfX, p.Z / BODY.halfZ
	local r = math.sqrt(nx * nx + nz * nz)
	if r >= 1 then
		return p
	end
	if r < 1e-3 or nz > 0.2 and math.abs(nx) < 0.5 then
		-- en el centro o por la espalda: pasar por delante del pecho
		return Vector3.new(p.X, p.Y, -BODY.halfZ)
	end
	return Vector3.new(nx / r * BODY.halfX, p.Y, nz / r * BODY.halfZ)
end

-- Distancia mínima entre dos segmentos (para que dos hojas choquen en el aire)
function Swing.SegmentDistance(p1, q1, p2, q2)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a <= 1e-6 and e <= 1e-6 then
		return r.Magnitude, p1
	end
	if a <= 1e-6 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-6 then
			t, s = 0, math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = denom ~= 0 and math.clamp((b * f - c * e) / denom, 0, 1) or 0
			t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t, s = 1, math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local c1, c2 = p1 + d1 * s, p2 + d2 * t
	return (c1 - c2).Magnitude, (c1 + c2) / 2
end

-- Pose del arma en espacio local: posición de las manos (empuñadura) y dirección de la hoja
-- st: { State, Kind ("slash"/"stab"), Angle, Phase ("windup"/"release"/"recovery"), T (0..1) }
local rawPose

function Swing.LocalPose(weapon, st)
	local hands, dir = rawPose(weapon, st)
	return Swing.ClearBody(hands), dir
end

rawPose = function(weapon, st)
	local reach = Config.Combat.ArmReach
	local guard = Swing.GuardDir(weapon)
	local guardHands = PIVOT + Vector3.new(0.35, -0.35, -0.85)
	local state, t = st.State, math.clamp(st.T or 0, 0, 1)
	if state == "attack" and st.Kind == "slash" then
		local cocked = Swing.SlashDir(st.Angle, -35)
		local startDir = Swing.SlashDir(st.Angle, -10)
		if st.Phase == "windup" then
			local k = ease(t)
			local dir = slerpDir(guard, cocked, k)
			local hands = guardHands:Lerp(PIVOT + Swing.SlashDir(st.Angle, 0) * (reach * 0.55), k)
			return hands, dir
		elseif st.Phase == "release" then
			local alpha = -10 + 205 * t
			local dir = Swing.SlashDir(st.Angle, alpha)
			local hands = PIVOT + dir * (reach * (0.6 + 0.4 * math.sin(rad(math.clamp(alpha, 0, 180)))))
			return hands, dir
		else
			local endDir = Swing.SlashDir(st.Angle, 195)
			local k = ease(t)
			local endHands = PIVOT + endDir * (reach * 0.6)
			return endHands:Lerp(guardHands, k), slerpDir(endDir, guard, k)
		end
	elseif state == "attack" and st.Kind == "stab" then
		local back = PIVOT + Vector3.new(0.35, -0.2, 0.15)
		local front = PIVOT + FORWARD * (reach + 0.7)
		if st.Phase == "windup" then
			local k = ease(t)
			return guardHands:Lerp(back, k), slerpDir(guard, FORWARD, k)
		elseif st.Phase == "release" then
			return back:Lerp(front, t), FORWARD
		else
			local k = ease(t)
			return front:Lerp(guardHands, k), slerpDir(FORWARD, guard, k)
		end
	elseif state == "parry" or state == "riposte" then
		-- arma cruzada delante de la cara
		local dir = Vector3.new(-0.85, 0.35, -0.4).Unit
		return PIVOT + Vector3.new(0.45, 0.35, -0.95), dir
	elseif state == "disarmed" then
		return PIVOT + Vector3.new(0.6, -0.9, -0.3), Vector3.new(0.3, -0.9, -0.3).Unit
	end
	return guardHands, guard
end

-- Hacia dónde mira el filo (local): en un corte, el filo va adelante en el sentido del movimiento de la hoja
function Swing.EdgeDir(st, dir)
	local edge
	if st.State == "attack" and st.Kind == "slash" then
		local side = Vector3.new(math.sin(rad(st.Angle)), math.cos(rad(st.Angle)), 0)
		local normal = side:Cross(FORWARD)
		edge = normal:Cross(dir)
		if st.Phase == "recovery" then
			edge = edge:Lerp(FORWARD, math.clamp(st.T or 0, 0, 1))
		end
	elseif st.State == "attack" and st.Kind == "stab" then
		edge = Vector3.yAxis
	elseif st.State == "parry" or st.State == "riposte" then
		edge = FORWARD -- filo hacia el golpe que viene
	else
		edge = Vector3.new(0, 0.3, -1)
	end
	edge = edge - dir * edge:Dot(dir)
	if edge.Magnitude < 1e-3 then
		edge = Vector3.yAxis - dir * dir.Y
	end
	return edge.Unit
end

-- Aplica el giro de mirada (pitch) y lleva la pose al mundo
function Swing.WorldPose(rootCF, pitch, weapon, st)
	local hands, dir = Swing.LocalPose(weapon, st)
	local edge = Swing.EdgeDir(st, dir)
	local tilt = CFrame.Angles(rad(math.clamp(pitch or 0, -60, 60) * 0.7), 0, 0)
	local rel = hands - PIVOT
	hands = Swing.ClearBody(PIVOT + tilt:VectorToWorldSpace(rel)) -- mirar arriba o abajo tampoco mete las manos en el cuerpo
	dir = tilt:VectorToWorldSpace(dir)
	edge = tilt:VectorToWorldSpace(edge)
	local base = rootCF:PointToWorldSpace(hands)
	local wdir = rootCF:VectorToWorldSpace(dir)
	return base, base + wdir * weapon.Length, wdir, rootCF:VectorToWorldSpace(edge)
end

-- Puntos a lo largo de la hoja (de la empuñadura a la punta) para barrer impactos
function Swing.BladePoints(base, tip, count)
	local points = {}
	for i = 1, count do
		local k = 0.35 + 0.65 * (i - 1) / math.max(1, count - 1)
		points[i] = base:Lerp(tip, k)
	end
	return points
end

-- Dos golpes "espejados" (para chamber): lo que para vos viene de la derecha, para el otro viene de su izquierda
function Swing.MirrorAngle(angle)
	return -angle
end

function Swing.AngleDiff(a, b)
	local d = (a - b) % 360
	if d > 180 then
		d -= 360
	end
	return math.abs(d)
end

return Swing
