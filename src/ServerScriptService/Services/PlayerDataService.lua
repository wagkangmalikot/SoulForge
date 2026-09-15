-- src/ServerScriptService/Services/PlayerDataService.lua
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService.ThirdParty.ProfileService)

local PlayerDataService = {}

local DEFAULT_DATA = {
	Character = {
		Level = 1,
		ClassId = "Tank",
		UnspentEXP = 0,
		Name = "",                    -- set at character creation (spec 2b), TextService-filtered
		HasCreatedCharacter = false,  -- gates whether the creation screen shows on join
	},
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData_v1", DEFAULT_DATA)

-- userId -> Profile
local profiles = {}
-- userId -> true while a load is in flight, used by the timeout watchdog
local loading = {}
-- userId -> true once onPlayerAdded has been invoked for them at all (never
-- cleared). Distinguishes "hasn't started loading yet" from "started and
-- failed" for WaitForProfile below -- see the comment there for why this
-- matters.
local attempted = {}

local LOAD_TIMEOUT_SECONDS = 15

local function onPlayerAdded(player: Player)
	attempted[player.UserId] = true
	loading[player.UserId] = true

	task.delay(LOAD_TIMEOUT_SECONDS, function()
		if loading[player.UserId] and player.Parent == Players then
			warn(("PlayerDataService: profile load timed out for %s, kicking"):format(player.Name))
			player:Kick("Your data is still loading from another server session. Please rejoin in a moment.")
		end
	end)

	-- LoadProfileAsync defaults to "ForceLoad" behavior (no not_released_handler
	-- passed), so ProfileService itself retries for a handful of steps and then
	-- steals the session lock from a server that is still holding it (spec 1a).
	-- It normally only returns nil if the game is shutting down or a hard
	-- DataStore error occurs, but it can also hard-error (ProfileService.lua
	-- ~line 1737) if a profile for this key is already registered in this
	-- server's session (e.g. the same player rapidly rejoins this same server
	-- before the prior session's async :Release() has finished unregistering
	-- it). Guard with pcall so that case gives an immediate, accurate kick
	-- instead of silently falling through to the 15s timeout.
	local loadOk, profile = pcall(function()
		return ProfileStore:LoadProfileAsync(tostring(player.UserId))
	end)

	loading[player.UserId] = nil

	if not loadOk then
		warn(("PlayerDataService: LoadProfileAsync errored for %s: %s"):format(player.Name, tostring(profile)))
		if player.Parent == Players then
			player:Kick("Your previous session on this server hasn't finished closing yet. Please rejoin.")
		end
		return
	end

	if not profile then
		-- Load never succeeded. The timeout above will have already kicked the
		-- player in most cases; guard here too in case LoadProfileAsync
		-- returned before the timeout fired.
		if player.Parent == Players then
			player:Kick("Failed to load your data. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- fills in any DEFAULT_DATA fields missing from old saves

	profile:ListenToRelease(function()
		profiles[player.UserId] = nil
		if player.Parent == Players then
			player:Kick("Your data session ended unexpectedly. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		-- Player left while we were loading.
		profile:Release()
		return
	end

	profiles[player.UserId] = profile
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player.UserId]
	if profile then
		profile:Release()
	end
end

-- Returns the player's active Profile, or nil. nil can mean any of:
--   1) the load is still in flight (call again after PlayerAdded resolves),
--   2) the load failed or errored (the player has already been kicked), or
--   3) the profile was released (session ended, player left, or server is
--      shutting down via BindToClose).
-- Callers must always nil-check the result rather than assuming a connected
-- player has a loaded profile.
function PlayerDataService.GetProfile(player: Player)
	return profiles[player.UserId]
end

-- Blocks the calling thread until this player's profile finishes loading
-- successfully, or they disconnect. Returns the Profile, or nil if the load
-- failed/errored (PlayerDataService has already kicked them in that case) or
-- they disconnected while waiting. For use by other hub-only server services
-- (e.g. CharacterCreationService) that need to inspect profile data before a
-- player's character spawns, without racing PlayerDataService's own async load.
--
-- Callers commonly reach this from their OWN Players.PlayerAdded connection
-- (e.g. CharacterCreationService.handlePlayer). Roblox does not guarantee the
-- firing order between independent connections on the same signal, so this
-- can run before onPlayerAdded below has had a chance to run at all -- not
-- just before it *finishes*. Checking `attempted` (only ever set true, at the
-- top of onPlayerAdded, never cleared) instead of `loading` distinguishes
-- "hasn't started yet" (keep polling) from "started and finished without a
-- profile" (a real failure -- give up). Checking `loading` alone collapsed
-- both cases into "give up", so a caller that won this race returned nil
-- before onPlayerAdded ever ran, even though the load would have succeeded a
-- moment later.
function PlayerDataService.WaitForProfile(player: Player)
	while player.Parent == Players do
		local profile = profiles[player.UserId]
		if profile then
			return profile
		end
		if attempted[player.UserId] and not loading[player.UserId] then
			-- onPlayerAdded ran to completion and did not produce a profile: real failure.
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			onPlayerRemoving(player)
		end
	end)
end

return PlayerDataService
