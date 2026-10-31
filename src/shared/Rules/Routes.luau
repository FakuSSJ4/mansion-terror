--!strict
-- Rutas de ida y de vuelta entre dos piezas. Sin APIs de Roblox.

local Routes = {}

-- Cada sentido recorre los puntos intermedios en su orden y termina en el centro de su destino.
function Routes.both<T>(points: { T }, centerA: T, centerB: T): ({ T }, { T })
	local forward = table.clone(points)
	table.insert(forward, centerB)
	local backward = {}
	for i = #points, 1, -1 do
		table.insert(backward, points[i])
	end
	table.insert(backward, centerA)
	return forward, backward
end

return Routes
