-- src/ServerScriptService/Services/CharacterCreationService.lua
-- Hub-only. Gates a player's very first spawn on completing character
-- creation (spec section 2b): a first-time player sees a creation screen
-- instead of auto-spawning; a returning player sees a Load/Create New choice
-- instead of silently skipping straight to spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local HubMapService = require(script.Parent.HubMapService)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)

local CharacterCreationService = {}

local function fireCharacterDataChanged(player: Player, profile)
	Net.Get("CharacterDataChanged"):FireClient(
		player,
		profile.Data.Character.Level,
		profile.Data.Character.UnspentEXP,
		profile.Data.Character.ClassId
	)
end

-- Rejects an unrecognized/tampered classId from the client rather than trusting it
-- outright -- "Tank" is always a safe fallback since it's the original, always-valid class.
local function validateClassId(classId: any): string
	if type(classId) == "string" and Classes[classId] then
		return classId
	end
	return "Tank"
end

-- Teleports character cleanly into the Hub's central sanctuary fountain plaza
local function moveCharacterToHubSpawn(character: Model)
	if ReplicatedStorage:GetAttribute("IsDungeon") then
		return
	end
	task.defer(function()
		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if rootPart and not ReplicatedStorage:GetAttribute("IsDungeon") then
			character:PivotTo(HubMapService.GetSpawnCFrame())
		end
	end)
	task.delay(0.12, function()
		if character and character.Parent and not ReplicatedStorage:GetAttribute("IsDungeon") then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				character:PivotTo(HubMapService.GetSpawnCFrame())
			end
		end
	end)
end

-- Guards against processing the same player twice. This matters for the same
-- reason DungeonSessionService's `hookedPlayers` guard does: PlayerAdded is
-- connected BEFORE looping over the initial GetPlayers() snapshot (so a
-- player who joins mid-loop, while an earlier player's yielding calls are
-- still in flight, is never missed) -- which creates a narrow window where a
-- player could be picked up by both the connection and the loop's snapshot.
local processedPlayers = {}
local actionInFlight = {}

-- Shared tail end of all three character-entry actions: spawn the character,
-- notify the client of the (possibly just-reset) profile data, and release
-- the in-flight guard. Pulled out because all three handlers otherwise repeat
-- this verbatim aside from the warn's context phrase.
local function loadCharacterAndNotify(player: Player, profile, context: string)
	-- LoadCharacter() can throw (rare); pcall so a disconnect or engine error
	-- here doesn't take down this whole handler.
	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
		fireCharacterDataChanged(player, profile)
	end)
	if not loadOk then
		warn(("CharacterCreationService: LoadCharacter failed for %s %s: %s"):format(player.Name, context, tostring(loadErr)))
	end

	if player.Character then
		moveCharacterToHubSpawn(player.Character)
	end

	actionInFlight[player.UserId] = nil
end

local function setupInitialEquipment(profile, classId: string)
	local char = profile.Data.Character
	if classId == "Mage" then
		char.EquippedEquipment = {
			Weapon = "ApprenticeStaff",
			Head = "ApprenticeHood",
			Body = "ApprenticeRobe",
			Arms = "ApprenticeBracers",
			Feet = "ApprenticeBoots",
		}
		char.EquippedWeapon = "ApprenticeStaff"
		char.StoredEquipment = {
			"ApprenticeStaff",
			"ApprenticeHood",
			"ApprenticeRobe",
			"ApprenticeBracers",
			"ApprenticeBoots",
			"RockhideStaff",
			"RockhideCowl",
			"RockhideRobes",
			"RockhideWraps",
			"RockhideStriders",
		}
	else
		char.EquippedEquipment = {
			Weapon = "StandardSword",
			Head = "StandardHelm",
			Body = "StandardChest",
			Arms = "StandardArms",
			Feet = "StandardFeet",
		}
		char.EquippedWeapon = "StandardSword"
		char.StoredEquipment = {
			"StandardSword",
			"StandardHelm",
			"StandardChest",
			"StandardArms",
			"StandardFeet",
			"RockhideFang",
			"RockhideHelm",
			"RockhideChest",
			"RockhideArms",
			"RockhideFeet",
		}
	end
end

local function handlePlayer(player: Player)
	if processedPlayers[player.UserId] then
		return
	end
	processedPlayers[player.UserId] = true

	-- A player in the initial GetPlayers() snapshot can disconnect while this
	-- function is yielded (WaitForProfile polls, LoadCharacter() yields).
	-- Operating on a now-stale Player instance could throw; without this
	-- pcall, an uncaught error here would abort processing for every other
	-- player still waiting in the same loop.
	local ok, err = pcall(function()
		local profile = PlayerDataService.WaitForProfile(player)
		if not profile then
			return -- load failed; PlayerDataService has already kicked them
		end

		-- In Studio Play Solo, auto-load directly into the Hub on load so you can
		-- immediately play and test in the Hub (unless TestCharacterCreation is set).
		local autoLoadInStudio = RunService:IsStudio() and not ReplicatedStorage:GetAttribute("TestCharacterCreation")
		if autoLoadInStudio then
			profile.Data.Character.Name = player.DisplayName
			profile.Data.Character.ClassId = "Mage"
			profile.Data.Character.HasCreatedCharacter = true
			profile.Data.Character.UnlockedSkills = table.clone(Classes.Mage.startingSkills)
			profile.Data.Character.EquippedSkills = table.clone(Classes.Mage.startingSkills)
			setupInitialEquipment(profile, "Mage")
			loadCharacterAndNotify(player, profile, "studio auto-load")
			return
		end

		if profile.Data.Character.HasCreatedCharacter then
			Net.Get("ShowCharacterChoice"):FireClient(player, profile.Data.Character.Level, profile.Data.Character.ClassId or "Mage")
		else
			Net.Get("ShowCharacterCreation"):FireClient(player)
		end
	end)
	if not ok then
		warn(("CharacterCreationService: handlePlayer failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

local function onSubmitCharacterCreation(player: Player, classId: any)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	local validatedClassId = validateClassId(classId)
	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = validatedClassId
	-- table.clone, not a direct reference -- Classes[validatedClassId].startingSkills must
	-- stay the same shared table for every player; SkillTreeService later mutates a
	-- character's own UnlockedSkills/EquippedSkills in place (table.insert), which would
	-- corrupt that shared class-data table for everyone if it weren't cloned here.
	profile.Data.Character.UnlockedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.EquippedSkills = table.clone(Classes[validatedClassId].startingSkills)
	setupInitialEquipment(profile, validatedClassId)
	profile.Data.Character.HasCreatedCharacter = true

	loadCharacterAndNotify(player, profile, "after submission")
end

local function onRequestLoadCharacter(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or not profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or nothing to load
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	loadCharacterAndNotify(player, profile, "on load")
end

local function onRequestCreateNewCharacter(player: Player, classId: any)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or not profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or nothing to overwrite
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	-- Resets progress (spec 2b) but keeps HasCreatedCharacter true -- this is
	-- an overwrite of an existing character, not a return to the first-timer
	-- state. If anything below throws, the profile must not end up looking
	-- like a fresh, uncreated one, or a rejoin would incorrectly show the
	-- first-timer creation screen instead of the choice screen. Setting
	-- HasCreatedCharacter is not part of this reset, so that risk doesn't
	-- apply here.
	local validatedClassId = validateClassId(classId)
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 999999
	profile.Data.Character.SkillPoints = 50
	profile.Data.Character.ClassId = validatedClassId
	profile.Data.Character.UnlockedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.EquippedSkills = table.clone(Classes[validatedClassId].startingSkills)
	profile.Data.Character.Name = player.DisplayName
	setupInitialEquipment(profile, validatedClassId)

	loadCharacterAndNotify(player, profile, "after create-new")
end

function CharacterCreationService.Start()
	-- Same reasoning as DungeonSessionService's identical line: gates spawning
	-- so it can be made explicit and uniform (via handlePlayer/LoadCharacter)
	-- for every player instead of relying on the engine's own auto-spawn timing.
	Players.CharacterAutoLoads = false

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			moveCharacterToHubSpawn(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Died:Connect(function()
					task.wait(Players.RespawnTime or 3)
					if player and player.Parent and not ReplicatedStorage:GetAttribute("IsDungeon") then
						local profile = PlayerDataService.GetProfile(player)
						if profile and profile.Data.Character.HasCreatedCharacter then
							loadCharacterAndNotify(player, profile, "respawn after death")
						end
					end
				end)
			end
		end)

		if player.Character then
			moveCharacterToHubSpawn(player.Character)
		end

		handlePlayer(player)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end

	-- Hub servers stay alive across many players joining and leaving, so
	-- these player-keyed tables must be cleared on disconnect. Otherwise a
	-- player who leaves and later rejoins this same server instance would
	-- find processedPlayers still true (handlePlayer would never re-fire
	-- ShowCharacterCreation/ShowCharacterChoice, leaving them stuck with no
	-- character and no UI) or actionInFlight still true (all three actions
	-- silently blocked forever).
	Players.PlayerRemoving:Connect(function(player: Player)
		processedPlayers[player.UserId] = nil
		actionInFlight[player.UserId] = nil
	end)

	Net.Get("SubmitCharacterCreation").OnServerEvent:Connect(onSubmitCharacterCreation)
	Net.Get("RequestLoadCharacter").OnServerEvent:Connect(onRequestLoadCharacter)
	Net.Get("RequestCreateNewCharacter").OnServerEvent:Connect(onRequestCreateNewCharacter)

	Net.Get("RequestCharacterState").OnServerEvent:Connect(function(player: Player)
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			if profile.Data.Character.HasCreatedCharacter then
				Net.Get("ShowCharacterChoice"):FireClient(player, profile.Data.Character.Level, profile.Data.Character.ClassId or "Mage")
			else
				Net.Get("ShowCharacterCreation"):FireClient(player)
			end
		end
	end)
end


return CharacterCreationService
