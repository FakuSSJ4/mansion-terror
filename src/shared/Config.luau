--!strict
-- Todos los valores de balance del juego.

local Config = {
	-- Jugador
	MaxHealth = 100,
	WalkSpeed = 12,
	RunSpeed = 20,
	StaminaSeconds = 6,
	StaminaRecoverySeconds = 10,

	-- Asesino
	KillerPatrolSpeed = 10,
	KillerChaseSpeed = 15,
	KillerSearchSpeed = 18,
	KillerStalkSpeed = 10,
	KillerDamage = 50,
	KillerHitCooldown = 3,
	KillerHitRange = 5,
	KillerStartRoom = "room3",
	KillerSightRange = 60,
	KillerHearRange = 20,
	KillerSenseRange = 10,
	KillerGlowRange = 14,
	KillerLoseTargetSeconds = 8,
	SearchRoomDistance = 4,
	SearchAfterSeconds = 120,
	RefugeCampSeconds = 30,
	RefugeStalkSeconds = 20,
	KillerStuckSeconds = 10,

	-- Objetos
	TaserStartCharges = 2,
	TaserRange = 15,
	TaserStunSeconds = 10,
	TaserImmunitySeconds = 5,
	TaserRechargeCount = 4,
	PillCount = 8,
	PillHeal = 50,
	InteractRange = 10,
	InteractCooldown = 0.2,

	-- Progreso
	KeyCount = 6,
	BookCount = 8,
	VictorySeconds = 15,

	-- Ambiente
	LightningInterval = 900,
	ScareRange = 30,
	ScareRearmSeconds = 20,
	MaxLightsPerRoom = 6,
}

return Config
