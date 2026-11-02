--!strict
-- Recorrido de la fuga: puntos {x, z} y una posición a cierta distancia. Sin APIs de Roblox.

local EscapePath = {}

export type Point = { number }

function EscapePath.length(points: { Point }): number
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	return total
end

-- Punto a `distance` del comienzo; se queda en el último si se pasa.
function EscapePath.pointAt(points: { Point }, distance: number): Point
	local remaining = math.max(distance, 0)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local segment = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		if remaining <= segment and segment > 0 then
			local alpha = remaining / segment
			return { a[1] + (b[1] - a[1]) * alpha, a[2] + (b[2] - a[2]) * alpha }
		end
		remaining -= segment
	end
	local last = points[#points]
	return { last[1], last[2] }
end

return EscapePath
