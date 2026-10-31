--!strict
-- Estados y temporizadores del asesino. No conoce posiciones ni APIs de Roblox.

export type State = "Patrol" | "Chase" | "Search" | "Stunned"

export type Brain = {
	state: State,
	target: string?,
	clock: number,
	stunUntil: number,
	immuneUntil: number,
	lostFor: number,
	farFor: number,
}

export type Input = {
	now: number,
	dt: number,
	visibleTarget: string?,
	-- nil si todos los jugadores están en refugios
	minRoomDistance: number?,
}

local KillerBrain = {}

function KillerBrain.new(): Brain
	return {
		state = "Patrol",
		target = nil,
		clock = 0,
		stunUntil = 0,
		immuneUntil = 0,
		lostFor = 0,
		farFor = 0,
	}
end

local function enter(b: Brain, state: State, target: string?)
	b.state = state
	b.target = target
end

function KillerBrain.step(b: Brain, input: Input, cfg: any): Brain
	if input.now < b.stunUntil then
		enter(b, "Stunned", nil)
		return b
	end
	if b.state == "Stunned" then
		enter(b, "Patrol", nil)
	end

	local distance = input.minRoomDistance
	if distance and distance >= cfg.SearchRoomDistance then
		b.farFor += input.dt
	else
		b.farFor = 0
	end

	if input.visibleTarget then
		b.lostFor = 0
		enter(b, "Chase", input.visibleTarget)
		return b
	end

	if b.state == "Chase" then
		b.lostFor += input.dt
		if b.lostFor >= cfg.KillerLoseTargetSeconds then
			enter(b, "Patrol", nil)
		else
			return b
		end
	end

	if b.state == "Search" then
		-- Sigue buscando hasta llegar a la pieza del jugador.
		if not distance or distance == 0 then
			enter(b, "Patrol", nil)
		end
	elseif b.farFor >= cfg.SearchAfterSeconds then
		enter(b, "Search", nil)
	end
	return b
end

-- Un jugador se fue o murió: si era el objetivo, se descarta en el acto.
function KillerBrain.dropTarget(b: Brain, playerId: string)
	if b.target == playerId then
		b.lostFor = 0
		enter(b, "Patrol", nil)
	end
end

return KillerBrain
