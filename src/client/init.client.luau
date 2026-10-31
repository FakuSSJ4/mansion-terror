--!strict
local Controllers = script:WaitForChild("Controllers")

for _, child in Controllers:GetChildren() do
	if child:IsA("ModuleScript") then
		(require(child) :: any).start()
	end
end
