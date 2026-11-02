--!strict
-- Polvo que cae del dintel con un portazo.

local Dust = {}

-- `position` es el centro del dintel; `across` el largo de la puerta y `along` el eje del portazo.
function Dust.burst(position: Vector3, across: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(math.max(math.abs(across.X), 1), 0.5, math.max(math.abs(across.Z), 1))
	anchor.Position = position
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	emitter.Size = NumberSequence.new(1.5, 4.5)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.LightInfluence = 0.5
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(amount)
	task.delay(3, function()
		anchor:Destroy()
	end)
end

return Dust
