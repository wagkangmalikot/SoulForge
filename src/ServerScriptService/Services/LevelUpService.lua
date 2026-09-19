-- src/ServerScriptService/Services/LevelUpService.lua
-- Hub-only. Souls-style manual leveling (spec section 9a): a player spends
-- UnspentEXP at a fixed cost (level x 50) to increase their Level by one.
-- No automatic EXP-threshold leveling -- this is the only way Level changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LevelUpService = {}

local function expCostForLevel(level: number): number
	return level * 50
end

local function tryLevelUp(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local character = profile.Data.Character
	local cost = expCostForLevel(character.Level)
	if character.UnspentEXP < cost then
		return -- not enough EXP -- silently reject; the client's own display
		       -- already shows the real cost, this is just the server gate
	end

	character.UnspentEXP -= cost
	character.Level += 1
	character.SkillPoints = (character.SkillPoints or 0) + 1

	Net.Get("CharacterDataChanged"):FireClient(player, character.Level, character.UnspentEXP)

	local SkillTreeService = require(script.Parent.SkillTreeService)
	SkillTreeService.SyncSkills(player)
end

function LevelUpService.Start()
	Net.Get("RequestLevelUp").OnServerEvent:Connect(function(player)
		tryLevelUp(player)
	end)

	-- Developer / Testing Chat Commands: /exp, /maxexp, /skills
	local function hookChat(player: Player)
		player.Chatted:Connect(function(msg)
			local cmd = string.lower(string.gsub(msg, "^%s*(.-)%s*$", "%1"))
			if cmd == "/exp" or cmd == "/maxexp" or cmd == "/skills" or cmd == "/testexp" or cmd == "/max"
				or cmd == "/money" or cmd == "/gold" or cmd == "/fragments" or cmd == "/mats" or cmd == "/unlimited" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					char.UnspentEXP = 999999
					char.SkillPoints = math.max(char.SkillPoints or 0, 50)
					char.Gold = 9999999
					char.CraftingMaterials = {
						RockhideFragment = 99999,
						IronIngot = 99999,
						OakTimber = 99999,
						LeatherStrap = 99999,
						SunstoneCore = 99999,
						AncientRune = 99999,
					}
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP)
					local SkillTreeService = require(script.Parent.SkillTreeService)
					SkillTreeService.SyncSkills(player)
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment or {},
						char.StoredEquipment or {},
						char.CraftingMaterials
					)
				end
			elseif cmd == "/rockhide" or cmd == "/testrockhide" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					local rockhidePieces = {"RockhideFang", "RockhideHelm", "RockhideChest", "RockhideArms", "RockhideFeet"}
					char.EquippedEquipment = {
						Weapon = "RockhideFang",
						Head = "RockhideHelm",
						Body = "RockhideChest",
						Arms = "RockhideArms",
						Feet = "RockhideFeet",
					}
					char.EquippedWeapon = "RockhideFang"
					for _, piece in ipairs(rockhidePieces) do
						if not table.find(char.StoredEquipment, piece) then
							table.insert(char.StoredEquipment, piece)
						end
					end
					local WeaponService = require(script.Parent.WeaponService)
					if player.Character then
						WeaponService.EquipWeapons(player.Character)
					end
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment,
						char.StoredEquipment,
						char.CraftingMaterials
					)
				end
			elseif cmd == "/standard" or cmd == "/teststandard" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					char.EquippedEquipment = {
						Weapon = "StandardSword",
						Head = "StandardHelm",
						Body = "StandardChest",
						Arms = "StandardArms",
						Feet = "StandardFeet",
					}
					char.EquippedWeapon = "StandardSword"
					local WeaponService = require(script.Parent.WeaponService)
					if player.Character then
						WeaponService.EquipWeapons(player.Character)
					end
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment,
						char.StoredEquipment,
						char.CraftingMaterials
					)
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(hookChat)
	for _, p in ipairs(Players:GetPlayers()) do
		hookChat(p)
	end
end

return LevelUpService
