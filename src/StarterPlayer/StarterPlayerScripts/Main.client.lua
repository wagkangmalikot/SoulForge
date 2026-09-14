-- src/StarterPlayer/StarterPlayerScripts/Main.client.lua
local HUDController = require(script.Parent.Controllers.HUDController)
local PartyUIController = require(script.Parent.Controllers.PartyUIController)
local DungeonPortalController = require(script.Parent.Controllers.DungeonPortalController)
local DownedUIController = require(script.Parent.Controllers.DownedUIController)

HUDController.Start()
PartyUIController.Start()
DungeonPortalController.Start()
DownedUIController.Start()
