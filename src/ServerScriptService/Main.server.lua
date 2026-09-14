-- src/ServerScriptService/Main.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local CombatService = require(ServerScriptService.Services.CombatService)

PlayerDataService.Start()
CombatService.Start()

print("Soulforge server started. Net remotes ready:", Net.Get("CastSkill").Name)
