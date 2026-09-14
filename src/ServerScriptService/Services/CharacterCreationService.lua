-- src/ServerScriptService/Services/CharacterCreationService.lua
-- Hub-only. Gates a player's very first spawn on completing character
-- creation (spec section 2b): a first-time player sees a creation screen
-- instead of auto-spawning; a returning player (profile already has
-- HasCreatedCharacter = true) spawns immediately, same as before this
-- feature existed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CharacterCreationService = {}

local MIN_NAME_LENGTH = 3
local MAX_NAME_LENGTH = 20

local function fireCharacterDataChanged(player: Player, profile)
	Net.Get("CharacterDataChanged"):FireClient(
		player,
		profile.Data.Character.Level,
		profile.Data.Character.UnspentEXP
	)
end

-- Guards against processing the same player twice. This matters for the same
-- reason DungeonSessionService's `hookedPlayers` guard does: PlayerAdded is
-- connected BEFORE looping over the initial GetPlayers() snapshot (so a
-- player who joins mid-loop, while an earlier player's yielding calls are
-- still in flight, is never missed) -- which creates a narrow window where a
-- player could be picked up by both the connection and the loop's snapshot.
local processedPlayers = {}

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

		if profile.Data.Character.HasCreatedCharacter then
			player:LoadCharacter()
			fireCharacterDataChanged(player, profile)
		else
			Net.Get("ShowCharacterCreation"):FireClient(player)
		end
	end)
	if not ok then
		warn(("CharacterCreationService: handlePlayer failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

local function onSubmitCharacterCreation(player: Player, characterName: string)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	local trimmed = characterName:gsub("^%s+", ""):gsub("%s+$", "")
	if #trimmed < MIN_NAME_LENGTH or #trimmed > MAX_NAME_LENGTH then
		Net.Get("CharacterCreationResult"):FireClient(
			player, false,
			("Name must be %d-%d characters."):format(MIN_NAME_LENGTH, MAX_NAME_LENGTH)
		)
		return
	end

	local filterOk, filterResultOrErr = pcall(function()
		local filterResult = TextService:FilterStringAsync(trimmed, player.UserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not filterOk then
		warn(("CharacterCreationService: FilterStringAsync failed for %s: %s"):format(player.Name, tostring(filterResultOrErr)))
		Net.Get("CharacterCreationResult"):FireClient(player, false, "Name filtering failed, please try again.")
		return
	end

	local filteredName = filterResultOrErr
	if filteredName == "" then
		Net.Get("CharacterCreationResult"):FireClient(player, false, "That name isn't allowed. Try another.")
		return
	end

	profile.Data.Character.Name = filteredName
	profile.Data.Character.ClassId = "Tank" -- the only implemented class (spec section 2a)
	profile.Data.Character.HasCreatedCharacter = true

	Net.Get("CharacterCreationResult"):FireClient(player, true)
	player:LoadCharacter()
	fireCharacterDataChanged(player, profile)
end

function CharacterCreationService.Start()
	-- Same reasoning as DungeonSessionService's identical line: gates spawning
	-- so it can be made explicit and uniform (via handlePlayer/LoadCharacter)
	-- for every player instead of relying on the engine's own auto-spawn timing.
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(handlePlayer)
	for _, player in Players:GetPlayers() do
		handlePlayer(player)
	end

	Net.Get("SubmitCharacterCreation").OnServerEvent:Connect(function(player, characterName)
		if type(characterName) ~= "string" then
			return
		end
		onSubmitCharacterCreation(player, characterName)
	end)
end

return CharacterCreationService
