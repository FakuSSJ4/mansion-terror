--!strict
-- Todos los valores de balance del juego.

local Config = {
	-- Jugador
	MaxHealth = 100,
	WalkSpeed = 12,
	RunSpeed = 20,
	DevWalkSpeed = 40,
	DevFlySpeed = 70,
	StaminaSeconds = 6,
	StaminaRecoverySeconds = 10,

	-- Asesino
	KillerPatrolSpeed = 10,
	KillerChaseSpeed = 15,
	KillerSearchSpeed = 18,
	KillerDamage = 50,
	KillerHitCooldown = 3,
	KillerHitPause = 2,
	KillerHitRange = 5,
	-- Las puertas lo encierran: arranca del lado abierto y espera antes de moverse.
	KillerStartRoom = "room1",
	KillerGraceSeconds = 20,
	KillerSightRange = 60,
	KillerHearRange = 20,
	KillerSenseRange = 10,
	KillerGlowRange = 14,
	KillerLoseTargetSeconds = 8,
	SearchRoomDistance = 4,
	SearchAfterSeconds = 120,
	KillerStuckSeconds = 10,

	-- Objetos
	TaserStartCharges = 1,
	TaserRange = 15,
	TaserStunSeconds = 10,
	TaserImmunitySeconds = 5,
	TaserSpareCount = 4,
	FlashlightSeconds = 120,
	BatteryRechargeSeconds = 60,
	BatteryCount = 6,
	PillCount = 8,
	PillHeal = 50,
	InteractRange = 10,
	InteractCooldown = 0.2,

	-- Progreso
	KeyCount = 6,
	KeyColors = {
		{ name = "roja", rgb = { 190, 40, 40 } },
		{ name = "azul", rgb = { 50, 90, 200 } },
		{ name = "verde", rgb = { 50, 150, 70 } },
		{ name = "violeta", rgb = { 130, 60, 180 } },
		{ name = "amarilla", rgb = { 220, 190, 50 } },
		{ name = "negra", rgb = { 18, 18, 20 } },
	},
	-- Dónde está cada llave: se alternan planta baja y primer piso para obligar a ir y venir.
	KeyRooms = { "room1", "room8", "room2", "room10", "room3", "room12" },
	-- Qué llave abre cada puerta. Las piezas 4 (cocina) y 6 quedan sin puerta con llave.
	DoorKeys = {
		room7 = 1,
		room7b = 1,
		room2 = 2,
		room9 = 3,
		room3 = 4,
		room11 = 5,
		room5 = 6,
	},
	GoldKeyRgb = { 235, 180, 40 },
	BookCount = 4,
	VictorySeconds = 15,
	DeathScreenSeconds = 4,

	-- Ambiente
	LightningInterval = 900,
	CrowInterval = 1200,
	ScareRange = 30,
	ScareRearmSeconds = 20,
	MaxLightsPerRoom = 6,
	LightFadeStart = 35,
	LightFadeEnd = 70,
}

return Config
