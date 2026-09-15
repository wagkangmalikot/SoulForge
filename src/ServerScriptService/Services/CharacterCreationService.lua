-- src/ServerScriptService/Services/CharacterCreationService.lua
-- Hub-only. Gates a player's very first spawn on completing character
-- creation (spec section 2b): a first-time player sees a creation screen
-- instead of auto-spawning; a returning player sees a Load/Create New choice
-- instead of silently skipping straight to spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CharacterCreationService = {}

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
			Net.Get("ShowCharacterChoice"):FireClient(player, profile.Data.Character.Level)
		else
			Net.Get("ShowCharacterCreation"):FireClient(player)
		end
	end)
	if not ok then
		warn(("CharacterCreationService: handlePlayer failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

-- Guards against a double-click/double-fire spamming any of the three
-- character-entry actions (submit creation, load, create-new) in quick
-- succession: OnServerEvent runs each fire on its own thread, so without this
-- a player could race two concurrent LoadCharacter() calls. Shared across all
-- three actions since a player can only be on one pre-spawn screen at a
-- time -- they're mutually exclusive by construction, so one flag is enough.
local actionInFlight = {}

local function onSubmitCharacterCreation(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Character.HasCreatedCharacter then
		return -- no profile, or already created: reject a resubmission
	end

	if actionInFlight[player.UserId] then
		return
	end
	actionInFlight[player.UserId] = true

	profile.Data.Character.Name = player.DisplayName
	profile.Data.Character.ClassId = "Tank" -- the only implemented class (spec section 2a)
	profile.Data.Character.HasCreatedCharacter = true

	-- LoadCharacter() can throw (rare); pcall so a disconnect or engine error
	-- here doesn't take down this whole handler.
	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
		fireCharacterDataChanged(player, profile)
	end)
	if not loadOk then
		warn(("CharacterCreationService: LoadCharacter failed for %s after submission: %s"):format(player.Name, tostring(loadErr)))
	end

	actionInFlight[player.UserId] = nil
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

	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
		fireCharacterDataChanged(player, profile)
	end)
	if not loadOk then
		warn(("CharacterCreationService: LoadCharacter failed for %s on load: %s"):format(player.Name, tostring(loadErr)))
	end

	actionInFlight[player.UserId] = nil
end

local function onRequestCreateNewCharacter(player: Player)
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
	profile.Data.Character.Level = 1
	profile.Data.Character.UnspentEXP = 0
	profile.Data.Character.ClassId = "Tank"
	profile.Data.Character.Name = player.DisplayName

	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
		fireCharacterDataChanged(player, profile)
	end)
	if not loadOk then
		warn(("CharacterCreationService: LoadCharacter failed for %s after create-new: %s"):format(player.Name, tostring(loadErr)))
	end

	actionInFlight[player.UserId] = nil
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

	Net.Get("SubmitCharacterCreation").OnServerEvent:Connect(onSubmitCharacterCreation)
	Net.Get("RequestLoadCharacter").OnServerEvent:Connect(onRequestLoadCharacter)
	Net.Get("RequestCreateNewCharacter").OnServerEvent:Connect(onRequestCreateNewCharacter)
end

return CharacterCreationService
