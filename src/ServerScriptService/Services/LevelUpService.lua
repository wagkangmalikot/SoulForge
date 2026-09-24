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

	Net.Get("CharacterDataChanged"):FireClient(player, character.Level, character.UnspentEXP, character.ClassId)

	local SkillTreeService = require(script.Parent.SkillTreeService)
	SkillTreeService.SyncSkills(player)

	local WeaponService = require(script.Parent.WeaponService)
	if player.Character then
		WeaponService.EquipWeapons(player.Character)
	end
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
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
					local SkillTreeService = require(script.Parent.SkillTreeService)
					SkillTreeService.SyncSkills(player)
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment or {},
						char.StoredEquipment or {},
						char.CraftingMaterials
					)
				end
			elseif cmd == "/reskill" or cmd == "/respec" then
				local SkillTreeService = require(script.Parent.SkillTreeService)
				SkillTreeService.ResetSkills(player)
			elseif cmd == "/rockhide" or cmd == "/testrockhide" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					local isMage = (char.ClassId == "Mage")
					local rockhidePieces = isMage
						and {"RockhideStaff", "RockhideCowl", "RockhideRobes", "RockhideWraps", "RockhideStriders"}
						or {"RockhideFang", "RockhideHelm", "RockhideChest", "RockhideArms", "RockhideFeet"}
					char.EquippedEquipment = isMage and {
						Weapon = "RockhideStaff",
						Head = "RockhideCowl",
						Body = "RockhideRobes",
						Arms = "RockhideWraps",
						Feet = "RockhideStriders",
					} or {
						Weapon = "RockhideFang",
						Head = "RockhideHelm",
						Body = "RockhideChest",
						Arms = "RockhideArms",
						Feet = "RockhideFeet",
					}
					char.EquippedWeapon = isMage and "RockhideStaff" or "RockhideFang"
					char.StoredEquipment = char.StoredEquipment or {}
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
			elseif cmd == "/sunforged" or cmd == "/testsunforged" or cmd == "/sun" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					local isMage = (char.ClassId == "Mage")
					local sunforgedPieces = isMage
						and {"SunforgedStaff", "SunforgedHood", "SunforgedRobes", "SunforgedWraps", "SunforgedSlippers"}
						or {"SunforgedSword", "SunforgedHelm", "SunforgedChest", "SunforgedArms", "SunforgedFeet"}
					char.EquippedEquipment = isMage and {
						Weapon = "SunforgedStaff",
						Head = "SunforgedHood",
						Body = "SunforgedRobes",
						Arms = "SunforgedWraps",
						Feet = "SunforgedSlippers",
					} or {
						Weapon = "SunforgedSword",
						Head = "SunforgedHelm",
						Body = "SunforgedChest",
						Arms = "SunforgedArms",
						Feet = "SunforgedFeet",
					}
					char.EquippedWeapon = isMage and "SunforgedStaff" or "SunforgedSword"
					char.StoredEquipment = char.StoredEquipment or {}
					for _, piece in ipairs(sunforgedPieces) do
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
			elseif string.sub(cmd, 1, 4) == "/lvl" or string.sub(cmd, 1, 9) == "/setlevel" then
				local targetLvl = tonumber(string.match(cmd, "%d+"))
				if targetLvl and targetLvl >= 1 then
					local profile = PlayerDataService.GetProfile(player)
					if profile and profile.Data.Character then
						local char = profile.Data.Character
						char.Level = math.clamp(targetLvl, 1, 100)
						char.SkillPoints = math.max(char.SkillPoints or 0, char.Level)
						Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
						local SkillTreeService = require(script.Parent.SkillTreeService)
						SkillTreeService.SyncSkills(player)
						local WeaponService = require(script.Parent.WeaponService)
						if player.Character then
							WeaponService.EquipWeapons(player.Character)
						end
					end
				end
			elseif cmd == "/standard" or cmd == "/teststandard" or cmd == "/starter" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					local isMage = (char.ClassId == "Mage")
					local starterPieces = isMage
						and {"ApprenticeStaff", "ApprenticeHood", "ApprenticeRobe", "ApprenticeBracers", "ApprenticeBoots"}
						or {"StandardSword", "StandardHelm", "StandardChest", "StandardArms", "StandardFeet"}
					char.EquippedEquipment = isMage and {
						Weapon = "ApprenticeStaff",
						Head = "ApprenticeHood",
						Body = "ApprenticeRobe",
						Arms = "ApprenticeBracers",
						Feet = "ApprenticeBoots",
					} or {
						Weapon = "StandardSword",
						Head = "StandardHelm",
						Body = "StandardChest",
						Arms = "StandardArms",
						Feet = "StandardFeet",
					}
					char.EquippedWeapon = isMage and "ApprenticeStaff" or "StandardSword"
					char.StoredEquipment = char.StoredEquipment or {}
					for _, piece in ipairs(starterPieces) do
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
			elseif cmd == "/mage" or cmd == "/makemage" or cmd == "/setmage" or cmd == "/class mage" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					char.ClassId = "Mage"
					char.UnlockedSkills = {"ArcaneBolt"}
					char.EquippedSkills = {"ArcaneBolt"}
					char.SkillPoints = math.max(char.SkillPoints or 0, 50)
					local magePieces = {"ApprenticeStaff", "ApprenticeHood", "ApprenticeRobe", "ApprenticeBracers", "ApprenticeBoots"}
					char.EquippedEquipment = {
						Weapon = "ApprenticeStaff",
						Head = "ApprenticeHood",
						Body = "ApprenticeRobe",
						Arms = "ApprenticeBracers",
						Feet = "ApprenticeBoots",
					}
					char.EquippedWeapon = "ApprenticeStaff"
					char.StoredEquipment = char.StoredEquipment or {}
					for _, piece in ipairs(magePieces) do
						if not table.find(char.StoredEquipment, piece) then
							table.insert(char.StoredEquipment, piece)
						end
					end
					local WeaponService = require(script.Parent.WeaponService)
					if player.Character then
						WeaponService.EquipWeapons(player.Character)
					end
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
					local SkillTreeService = require(script.Parent.SkillTreeService)
					SkillTreeService.SyncSkills(player)
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment,
						char.StoredEquipment,
						char.CraftingMaterials
					)
				end
			elseif cmd == "/tank" or cmd == "/maketank" or cmd == "/settank" or cmd == "/class tank" then
				local profile = PlayerDataService.GetProfile(player)
				if profile and profile.Data.Character then
					local char = profile.Data.Character
					char.ClassId = "Tank"
					char.UnlockedSkills = {"Taunt"}
					char.EquippedSkills = {"Taunt"}
					char.SkillPoints = math.max(char.SkillPoints or 0, 50)
					local tankPieces = {"StandardSword", "StandardHelm", "StandardChest", "StandardArms", "StandardFeet"}
					char.EquippedEquipment = {
						Weapon = "StandardSword",
						Head = "StandardHelm",
						Body = "StandardChest",
						Arms = "StandardArms",
						Feet = "StandardFeet",
					}
					char.EquippedWeapon = "StandardSword"
					char.StoredEquipment = char.StoredEquipment or {}
					for _, piece in ipairs(tankPieces) do
						if not table.find(char.StoredEquipment, piece) then
							table.insert(char.StoredEquipment, piece)
						end
					end
					local WeaponService = require(script.Parent.WeaponService)
					if player.Character then
						WeaponService.EquipWeapons(player.Character)
					end
					Net.Get("CharacterDataChanged"):FireClient(player, char.Level, char.UnspentEXP, char.ClassId)
					local SkillTreeService = require(script.Parent.SkillTreeService)
					SkillTreeService.SyncSkills(player)
					Net.Get("EquipmentDataChanged"):FireClient(
						player,
						char.EquippedEquipment,
						char.StoredEquipment,
						char.CraftingMaterials
					)
				end
			elseif cmd == "/sunforged" or cmd == "/citadel" or cmd == "/dungeon2" then
				local DungeonEntryService = require(script.Parent.DungeonEntryService)
				DungeonEntryService.EnterDungeon(player, "Sunforged")
			elseif cmd == "/rockhide" or cmd == "/dungeon1" then
				local DungeonEntryService = require(script.Parent.DungeonEntryService)
				DungeonEntryService.EnterDungeon(player, "Rockhide")
			elseif cmd == "/boss" or cmd == "/solarius" or cmd == "/bossfight" or cmd == "/opengate" then
				local DungeonSessionService = require(script.Parent.DungeonSessionService)
				if DungeonSessionService.OpenBossGateForTesting then
					DungeonSessionService.OpenBossGateForTesting()
				end
				if player.Character then
					local isCitadel = workspace:FindFirstChild("SunforgedCitadel") ~= nil
					local targetCF = isCitadel and CFrame.new(0, 52, -45) or CFrame.new(0, 5, -20)
					player.Character:PivotTo(targetCF)
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.AssemblyLinearVelocity = Vector3.zero
						hrp.AssemblyAngularVelocity = Vector3.zero
					end
					Net.Get("TeleportClient"):FireClient(player, targetCF)
				end
			elseif cmd == "/clearmobs" or cmd == "/killmobs" or cmd == "/slayall" then
				local CombatService = require(script.Parent.CombatService)
				for _, desc in workspace:GetChildren() do
					if desc:IsA("Model") and string.find(desc.Name, "TrashMob") then
						local enemyHandle = CombatService.GetEnemy(desc.Name)
						if enemyHandle and enemyHandle.onDamaged then
							enemyHandle.onDamaged(999999, player)
						end
					end
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
