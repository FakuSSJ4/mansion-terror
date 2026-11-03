--!strict
-- Único lugar con ID de audio. Un ID vacío o que no carga deja el juego en silencio, sin errores.
-- Todos salen del catálogo gratuito (Creator Store) y se comprobaron cargando en Studio; si alguno
-- se bloquea al publicar, se cambia acá sin tocar nada más.

local function asset(id: number): string
	return `rbxassetid://{id}`
end

return {
	-- Ambiente de la mansión.
	Rain = asset(5828281985),
	Thunder = asset(4961240438),
	Crow = asset(5829815715),
	Drone = asset(9112795583),
	Heartbeat = asset(6202853067),
	Drip = asset(9120607899),
	Wind = asset(9113286969),
	-- Golpes y sustos.
	Scare = asset(1843035239),
	Hit = asset(126976659766267),
	Taser = asset(9114277757),
	Growl = asset(9113980319),
	PigGrunt = asset(9117344600),
	-- Puertas y muebles.
	DoorSlam = asset(3908308607),
	DoorPound = asset(132982750965021),
	DoorCreak = asset(9120839010),
	MetalDoor = asset(9116604303),
	Drawer = asset(9113657277),
	-- Interfaz y objetos.
	Pickup = asset(7381723507),
	FlashlightClick = asset(9114480271),
	Buy = asset(131737037329240),
	-- Fin de partida.
	Win = asset(138132318456925),
	GameOver = asset(9040342348),
	-- Lobby.
	LobbyMusic = asset(113205710506304),
	Fountain = asset(136569006780446),
}
