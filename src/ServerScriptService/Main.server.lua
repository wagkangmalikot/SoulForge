-- src/ServerScriptService/Main.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

print("Soulforge server started. Net remotes ready:", Net.Get("CastSkill").Name)
