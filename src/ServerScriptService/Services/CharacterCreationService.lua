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

-- Guards against a double-click or spammed client firing two
-- SubmitCharacterCreation events in quick succession: OnServerEvent runs each
-- fire on its own thread, so without this both would pass the
-- HasCreatedCharacter check below and proceed concurrently across the
-- FilterStringAsync yield -- double-mutating the profile, double-spawning the
-- character, double-firing the result/data-changed remotes, and piling up
-- concurrent (server-rate-limited) filter calls. Set before any yield in
-- onSubmitCharacterCreation; cleared on every exit path (success or
-- rejection) so a legitimate retry after a real rejection (e.g. a bad name)
-- isn't permanently blocked.
local submitting = {}

local function onSubmitCharacterCreation(player: Player, characterName: string)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	if submitting[player.UserId] then
		return -- a previous submission from this player is still in flight
	end
	submitting[player.UserId] = true

	local trimmed = characterName:gsub("^%s+", ""):gsub("%s+$", "")
	-- utf8.len counts codepoints, not bytes. Lua's `#` counts UTF-8 bytes, so
	-- a reasonable-length non-Latin name (Japanese, Korean, Cyrillic, Arabic,
	-- ...) can be well within a sane visual length but still trip a
	-- byte-counted MAX_NAME_LENGTH. Do not swap this back to `#`. utf8.len
	-- returns nil on malformed UTF-8, which is also treated as invalid below.
	local length = utf8.len(trimmed)
	if not length or length < MIN_NAME_LENGTH or length > MAX_NAME_LENGTH then
		Net.Get("CharacterCreationResult"):FireClient(
			player, false,
			("Name must be %d-%d characters."):format(MIN_NAME_LENGTH, MAX_NAME_LENGTH)
		)
		submitting[player.UserId] = nil
		return
	end

	local filterOk, filterResultOrErr = pcall(function()
		local filterResult = TextService:FilterStringAsync(trimmed, player.UserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not filterOk then
		warn(("CharacterCreationService: FilterStringAsync failed for %s: %s"):format(player.Name, tostring(filterResultOrErr)))
		Net.Get("CharacterCreationResult"):FireClient(player, false, "Name filtering failed, please try again.")
		submitting[player.UserId] = nil
		return
	end

	local filteredName = filterResultOrErr
	if filteredName == "" then
		Net.Get("CharacterCreationResult"):FireClient(player, false, "That name isn't allowed. Try another.")
		submitting[player.UserId] = nil
		return
	end

	profile.Data.Character.Name = filteredName
	profile.Data.Character.ClassId = "Tank" -- the only implemented class (spec section 2a)
	profile.Data.Character.HasCreatedCharacter = true

	Net.Get("CharacterCreationResult"):FireClient(player, true)

	-- Unlike handlePlayer's equivalent call, this one wasn't previously
	-- guarded: if the player disconnected during the FilterStringAsync yield
	-- above, LoadCharacter() can throw here -- after the profile has already
	-- been mutated and success already reported -- leaving them stuck with no
	-- character and nothing left to retry. pcall it, consistent with how
	-- handlePlayer already treats this same call as fallible.
	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
		fireCharacterDataChanged(player, profile)
	end)
	if not loadOk then
		warn(("CharacterCreationService: LoadCharacter failed for %s after submission: %s"):format(player.Name, tostring(loadErr)))
	end

	submitting[player.UserId] = nil
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
