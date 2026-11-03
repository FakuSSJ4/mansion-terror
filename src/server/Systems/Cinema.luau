--!strict
-- Primer encuentro con el villano: el asesino principal mira una película en blanco y negro en el
-- living, sentado en su sillón con un whisky. La primera vez que alguien entra a la pieza se ve la
-- escena (los clientes ponen la cámara, ver Controllers/Cinema); al terminar se levanta y sale a
-- cazar. Si nadie entra a tiempo, se levanta solo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local Killer = require(Systems:WaitForChild("Killer"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Cinema = {}

local ROOM = "room1"

local seatKiller: () -> () = function() end
local isPlaying = false

-- Solo para QA: vuelve a sentarlo para repetir la escena.
function Cinema.debugReset()
	if not isPlaying then
		Killer.skipEncounter()
		seatKiller()
	end
end

function Cinema.start(refs: Mansion.MansionRefs)
	local cinema = refs.cinema
	local scene = cinema.propAxe.Parent
	-- Sentado esperando a que alguien entre.
	local waiting = false
	local startedAt: number? = nil
	local viewers: { Player } = {}

	local function glassOnTable()
		cinema.tableGlass.Parent = scene
		cinema.propAxe.Parent = nil
	end

	seatKiller = function()
		waiting = true
		isPlaying = false
		cinema.tableGlass.Parent = nil
		cinema.propAxe.Parent = scene
		Killer.sitMain(cinema.seat, cinema.glass)
	end

	local function finished()
		isPlaying = false
		for _, player in viewers do
			player:SetAttribute("Watching", false)
			if player.Parent then
				Remotes.get("Cinema"):FireClient(player, { done = true })
			end
		end
		viewers = {}
	end

	local function play(trigger: Player)
		waiting = false
		isPlaying = true
		local root = Vitality.rootOf(trigger)
		local watcher = if root then root.Position else cinema.stand
		viewers = {}
		for _, player in Round.participants() do
			if Vitality.isPlaying(player) and Vitality.rootOf(player) then
				table.insert(viewers, player)
				player:SetAttribute("Watching", true)
				Remotes.get("Cinema"):FireClient(player, {
					seat = cinema.seat.Position,
					forward = cinema.seat.LookVector,
					stand = cinema.stand,
					screen = cinema.screen,
					projector = cinema.projector,
					tableTop = cinema.tableTop,
					watcher = watcher,
					seconds = Config.Cinema.seconds,
				})
			end
		end
		Killer.encounterMain(watcher, cinema.stand, cinema.floorY, glassOnTable, finished)
	end

	seatKiller()
	-- Killer rearma a los asesinos con el mismo aviso: se lo sienta después.
	Round.Reset:Connect(function()
		startedAt = nil
		task.defer(seatKiller)
	end)
	Round.Started:Connect(function()
		startedAt = os.clock()
	end)

	-- Cualquiera de los que miran puede saltear la escena: se corta para todos.
	Remotes.get("CinemaSkip").OnServerEvent:Connect(function(player)
		if isPlaying and table.find(viewers, player) then
			Killer.skipEncounter()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			if waiting and not isPlaying then
				for _, player in Round.participants() do
					if Vitality.isPlaying(player) and Vitality.getRoom(player) == ROOM then
						play(player)
						break
					end
				end
			end
			-- Nadie vino a verlo: se levanta solo, sin escena.
			if
				waiting
				and not isPlaying
				and startedAt
				and os.clock() - startedAt > Config.Cinema.maxWait
			then
				waiting = false
				Killer.encounterMain(
					cinema.screen,
					cinema.stand,
					cinema.floorY,
					glassOnTable,
					function() end
				)
				Killer.skipEncounter()
			end
		end
	end)
end

return Cinema
