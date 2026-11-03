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
	Killers = {
		-- Recorre toda la casa; hacen falta 3 golpes.
		main = {
			damage = 34,
			patrolSpeed = 10,
			chaseSpeed = 15,
			searchSpeed = 18,
			-- Arranca lejos del hall (donde aparecen los jugadores), a tres piezas de distancia.
			startRoom = "room3",
		},
		-- El del smoking: más lento, 2 golpes y solo en el primer piso, sin subir al cobertizo.
		gentleman = {
			damage = 50,
			patrolSpeed = 7,
			chaseSpeed = 11,
			searchSpeed = 13,
			startRoom = "room8",
			rooms = {
				room7 = true,
				room8 = true,
				room9 = true,
				room10 = true,
				room11 = true,
				room12 = true,
				bar = true,
			},
		},
		-- Los carniceros (son dos): andan por todo el sótano y, por la escalera, llegan hasta la cocina
		-- (la pieza donde termina), pero no salen de ahí. 5 golpes, y un 20 % más rápidos que antes.
		butcher = {
			damage = 20,
			patrolSpeed = 14.4,
			chaseSpeed = 20.4,
			searchSpeed = 24,
			startRoom = "room6",
			rooms = {
				room4 = true,
				room5 = true,
				room6 = true,
			},
		},
		butcher2 = {
			damage = 20,
			patrolSpeed = 14.4,
			chaseSpeed = 20.4,
			searchSpeed = 24,
			startRoom = "room5",
			rooms = {
				room4 = true,
				room5 = true,
				room6 = true,
			},
		},
	},
	-- Dificultades: cuánto cambian el daño y la velocidad de todos los asesinos. Normal es lo predeterminado.
	-- Pesadilla se desbloquea al ganar NightmareUnlockWins partidas en Normal.
	Difficulties = {
		easy = { name = "Fácil", damage = 0.7, speed = 0.85 },
		normal = { name = "Normal", damage = 1, speed = 1 },
		nightmare = { name = "Pesadilla", damage = 1.3, speed = 1.15 },
	},
	NightmareUnlockWins = 3,
	KillerHitCooldown = 3,
	KillerHitPause = 2,
	KillerHitRange = 5,
	-- Las puertas lo encierran: arranca del lado abierto y espera antes de moverse.
	KillerGraceSeconds = 45,
	KillerSightRange = 60,
	-- Oído: a cuántos studs oye a alguien que corre y a alguien que camina (agachado o quieto, a nadie).
	KillerHearRange = 34,
	KillerHearWalkRange = 9,
	KillerSenseRange = 10,
	-- Ángulo total de su cono de visión: lo que está fuera del cono no lo ve, ni siquiera de cerca.
	KillerFov = 110,
	-- Agachado: más lento, más bajo (escondible detrás de muebles) y casi no hace ruido.
	CrouchSpeed = 6,
	CrouchScale = 0.62,
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
	FlashlightSeconds = 180,
	BatteryRechargeSeconds = 60,
	BatteryCount = 6,
	-- Curas escondidas, mitad vendas y mitad botiquines (el botiquín cura más).
	CureCount = 8,
	BandageHeal = 25,
	MedkitHeal = 75,
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
	-- Piezas con una caja fuerte en la pared, cerrada con código; en cada una hay un pergamino. El código de la
	-- caja fuerte N (de tres cifras, distinto en cada partida) aparece escrito en una nota por la casa.
	VaultRooms = { "room1", "room3", "room9", "room10" },
	VictorySeconds = 15,
	-- Secuencia de fuga: todo en segundos desde que el jugador cruza la puerta del túnel.
	EscapeSeconds = 17,
	EscapeSpeed = 18,
	-- Metros por segundo del recorrido del jugador por el túnel.
	EscapeRunSpeed = 15,
	EscapeKillerStart = 0.7,
	EscapeKillerSpeed = 24,
	EscapeSlamAt = 2.45,
	EscapeFirstStrike = 3.0,
	EscapeStrikeEvery = 0.55,
	DeathScreenSeconds = 4,
	-- Entrada: los jugadores cruzan la puerta principal desde el patio y se cierra de un portazo.
	EntranceSeconds = 8,
	EntranceSpeed = 9,
	EntranceOpenAt = 0.5,
	EntranceSlamAt = 5.4,
	-- Primer encuentro: el asesino principal mira la película en el living hasta que alguien entra.
	-- Si nadie entra en ese tiempo, se levanta solo y sale a cazar.
	-- Segundos de cada momento de la escena: toma, gira hacia los jugadores, deja el vaso y se para,
	-- y ruge con el hacha en alto.
	Cinema = {
		seconds = 10,
		maxWait = 150,
		drinkAt = 3,
		turnAt = 5.8,
		standAt = 7.2,
		roarAt = 8.6,
	},

	-- Tienda del lobby: lo que se compra con gemas y dura para siempre.
	Shop = {
		armor = {
			name = "Armadura",
			description = "Los asesinos te hacen un 20% menos de daño.",
			price = 4,
			damageReduction = 0.2,
		},
		stamina = {
			name = "Resistencia",
			description = "Tu barra de estamina dura el doble.",
			price = 6,
			staminaMult = 2,
		},
	} :: {
		[string]: {
			name: string,
			description: string,
			price: number,
			damageReduction: number?,
			staminaMult: number?,
		},
	},
	-- Gemas escondidas en cada partida (mínimo y máximo).
	GemsMin = 1,
	GemsMax = 5,

	-- Ambiente
	-- Prueba de oscuridad: con false no hay velas ni llamas de candelabro, solo la linterna.
	CandlesLit = false,
	Storm = {
		WindowsMinutes = { 3, 5, 8 },
		QuietSeconds = 60,
		StrikesPerWindowMinute = 0.8,
		MinStrikes = 2,
	},
	CrowInterval = 1200,
	ScareRange = 30,
	ScareRearmSeconds = 20,
	MaxLightsPerRoom = 6,
	LightFadeStart = 35,
	LightFadeEnd = 70,
}

return Config
