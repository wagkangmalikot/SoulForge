local StarterGui = game:GetService("StarterGui")

-- Disable Roblox default CoreGui health bar (top-right) so only the custom HUD health bar displays
task.spawn(function()
	local success = false
	local attempts = 0
	while not success and attempts < 30 do
		attempts += 1
		success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if not success then
			task.wait(0.15)
		end
	end
end)

local controllers = {
	{"HUDController", script.Parent.Controllers.HUDController},
	{"PartyUIController", script.Parent.Controllers.PartyUIController},
	{"DungeonPortalController", script.Parent.Controllers.DungeonPortalController},
	{"DownedUIController", script.Parent.Controllers.DownedUIController},
	{"CharacterCreationController", script.Parent.Controllers.CharacterCreationController},
	{"LevelUpUIController", script.Parent.Controllers.LevelUpUIController},
	{"WeaponController", script.Parent.Controllers.WeaponController},
	{"SkillTreeUIController", script.Parent.Controllers.SkillTreeUIController},
	{"CraftingUIController", script.Parent.Controllers.CraftingUIController},
	{"InventoryUIController", script.Parent.Controllers.InventoryUIController},
}

for _, entry in controllers do
	local name, moduleScript = entry[1], entry[2]
	task.spawn(function()
		local ok, ctrl = pcall(require, moduleScript)
		if not ok then
			warn(("[Main.client] Failed to require controller %s: %s"):format(name, tostring(ctrl)))
			return
		end
		if ctrl and typeof(ctrl.Start) == "function" then
			local startOk, startErr = pcall(ctrl.Start)
			if not startOk then
				warn(("[Main.client] Failed to start controller %s: %s"):format(name, tostring(startErr)))
			end
		end
	end)
end

