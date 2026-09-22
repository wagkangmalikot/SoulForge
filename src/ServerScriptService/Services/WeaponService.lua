-- src/ServerScriptService/Services/WeaponService.lua
-- Equips Tank characters with Sword and Shield on spawn.
-- Supports multiple equipment tiers (Standard Adventurer set and Sunforged Relic set).
-- Manages welded weapon models, Motor6D grips, trails, and equipment switching for future crafting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EquipmentData = require(ReplicatedStorage.Shared.Data.Equipment)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)

local WeaponService = {}

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldParts(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end

local function addMesh(part: BasePart, meshType: Enum.MeshType, scale: Vector3?, meshId: string?, textureId: string?): SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType
	if scale then
		mesh.Scale = scale
	end
	if meshId then
		mesh.MeshId = meshId
	end
	if textureId then
		mesh.TextureId = textureId
	end
	mesh.Parent = part
	return mesh
end

-- ============================================================================
-- 1. STANDARD EQUIPMENT SET (Tier 1 Regular Adventurer Gear)
-- ============================================================================

local function createStandardSwordModel(): (Model, BasePart, Trail)
	local sword = Instance.new("Model")
	sword.Name = "EquippedSword"

	-- Handle / Grip Root (wrapped dark leather)
	local handle = makePart(sword, "Handle", Vector3.new(0.24, 1.10, 0.24), Color3.fromRGB(44, 30, 20), Enum.Material.Wood)
	sword.PrimaryPart = handle

	-- Grip Leather Rib Wraps
	for _, yOffset in {-0.28, -0.09, 0.10, 0.29} do
		local wrap = makePart(sword, "GripWrap", Vector3.new(0.27, 0.08, 0.27), Color3.fromRGB(32, 22, 14), Enum.Material.Fabric)
		wrap.CFrame = handle.CFrame * CFrame.new(0, yOffset, 0)
		addMesh(wrap, Enum.MeshType.Sphere, Vector3.new(1.05, 0.5, 1.05))
		weldParts(handle, wrap)
	end

	-- Octagonal Steel Wheel Pommel with Brass Center Button
	local pommel = makePart(sword, "Pommel", Vector3.new(0.42, 0.22, 0.42), Color3.fromRGB(48, 52, 60), Enum.Material.Metal)
	pommel.CFrame = handle.CFrame * CFrame.new(0, -0.65, 0)
	addMesh(pommel, Enum.MeshType.Sphere, Vector3.new(1.0, 0.65, 1.0))
	weldParts(handle, pommel)

	local pommelButton = makePart(sword, "PommelButton", Vector3.new(0.18, 0.12, 0.18), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
	pommelButton.CFrame = handle.CFrame * CFrame.new(0, -0.78, 0)
	addMesh(pommelButton, Enum.MeshType.Sphere)
	weldParts(handle, pommelButton)

	-- Sculpted Antique Brass Crossguard with Downturned Quillons
	local guardCenter = makePart(sword, "CrossguardCenter", Vector3.new(0.62, 0.28, 0.38), Color3.fromRGB(188, 145, 55), Enum.Material.Metal)
	guardCenter.CFrame = handle.CFrame * CFrame.new(0, 0.65, 0)
	addMesh(guardCenter, Enum.MeshType.Torso, Vector3.new(1.0, 0.8, 0.9))
	weldParts(handle, guardCenter)

	-- Left Quillon Bar & Finial
	local leftBar = makePart(sword, "LeftQuillonBar", Vector3.new(0.45, 0.18, 0.24), Color3.fromRGB(175, 135, 48), Enum.Material.Metal)
	leftBar.CFrame = handle.CFrame * CFrame.new(-0.48, 0.62, 0) * CFrame.Angles(0, 0, math.rad(-8))
	weldParts(handle, leftBar)

	local leftFinial = makePart(sword, "LeftFinial", Vector3.new(0.18, 0.26, 0.22), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
	leftFinial.CFrame = handle.CFrame * CFrame.new(-0.76, 0.58, 0)
	addMesh(leftFinial, Enum.MeshType.Sphere)
	weldParts(handle, leftFinial)

	-- Right Quillon Bar & Finial
	local rightBar = makePart(sword, "RightQuillonBar", Vector3.new(0.45, 0.18, 0.24), Color3.fromRGB(175, 135, 48), Enum.Material.Metal)
	rightBar.CFrame = handle.CFrame * CFrame.new(0.48, 0.62, 0) * CFrame.Angles(0, 0, math.rad(8))
	weldParts(handle, rightBar)

	local rightFinial = makePart(sword, "RightFinial", Vector3.new(0.18, 0.26, 0.22), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
	rightFinial.CFrame = handle.CFrame * CFrame.new(0.76, 0.58, 0)
	addMesh(rightFinial, Enum.MeshType.Sphere)
	weldParts(handle, rightFinial)

	-- Steel Blade Ricasso / Collar
	local collar = makePart(sword, "BladeCollar", Vector3.new(0.48, 0.25, 0.22), Color3.fromRGB(50, 55, 64), Enum.Material.Metal)
	collar.CFrame = handle.CFrame * CFrame.new(0, 0.88, 0)
	weldParts(handle, collar)

	-- Main Forged Steel Blade (Sleek proportions, dark tempered core with bright steel edge bevels)
	local bladeSpine = makePart(sword, "BladeSpine", Vector3.new(0.48, 3.2, 0.12), Color3.fromRGB(52, 58, 68), Enum.Material.Metal)
	bladeSpine.CFrame = handle.CFrame * CFrame.new(0, 2.50, 0)
	weldParts(handle, bladeSpine)

	local bladeEdge = makePart(sword, "BladeEdge", Vector3.new(0.54, 3.1, 0.08), Color3.fromRGB(140, 150, 162), Enum.Material.Metal)
	bladeEdge.CFrame = handle.CFrame * CFrame.new(0, 2.50, 0)
	weldParts(handle, bladeEdge)

	-- Central Fuller Groove (Dark inset line down center)
	local fuller = makePart(sword, "BladeFuller", Vector3.new(0.12, 2.6, 0.14), Color3.fromRGB(38, 42, 50), Enum.Material.Metal)
	fuller.CFrame = handle.CFrame * CFrame.new(0, 2.45, 0)
	weldParts(handle, fuller)

	-- Spearpoint Blade Tip
	local tipMid = makePart(sword, "BladeTipMid", Vector3.new(0.42, 0.45, 0.10), Color3.fromRGB(145, 155, 168), Enum.Material.Metal)
	tipMid.CFrame = handle.CFrame * CFrame.new(0, 4.25, 0)
	addMesh(tipMid, Enum.MeshType.Wedge)
	weldParts(handle, tipMid)

	local tipPoint = makePart(sword, "BladeTipPoint", Vector3.new(0.22, 0.38, 0.08), Color3.fromRGB(155, 165, 178), Enum.Material.Metal)
	tipPoint.CFrame = handle.CFrame * CFrame.new(0, 4.60, 0)
	addMesh(tipPoint, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.7))
	weldParts(handle, tipPoint)

	-- Trail Attachments
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 0.7, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 4.8, 0)
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 220, 240)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 155, 180)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.20
	trail.Enabled = false
	trail.Parent = handle

	return sword, handle, trail
end

local function createStandardShieldModel(): (Model, BasePart)
	local shield = Instance.new("Model")
	shield.Name = "EquippedShield"

	-- Handle / Attachment root
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = shield
	shield.PrimaryPart = handle

	-- Forearm mount straps
	local forearmStrap = makePart(shield, "ForearmStrap", Vector3.new(0.75, 0.35, 0.12), Color3.fromRGB(48, 34, 24), Enum.Material.Fabric)
	forearmStrap.CFrame = handle.CFrame * CFrame.new(-0.25, 0.45, -0.22)
	weldParts(handle, forearmStrap)

	local gripBar = makePart(shield, "GripBar", Vector3.new(0.16, 0.65, 0.16), Color3.fromRGB(50, 55, 64), Enum.Material.Metal)
	gripBar.CFrame = handle.CFrame * CFrame.new(0, -0.10, -0.24)
	weldParts(handle, gripBar)

	-- Backing Timber
	local innerBacking = makePart(shield, "ShieldInnerBacking", Vector3.new(2.4, 2.4, 0.10), Color3.fromRGB(52, 36, 22), Enum.Material.WoodPlanks)
	innerBacking.CFrame = handle.CFrame * CFrame.new(0, 0, -0.14)
	weldParts(handle, innerBacking)

	-- Front: Weathered Oak Timber Face
	local woodFace = makePart(shield, "ShieldWoodFace", Vector3.new(2.6, 2.6, 0.18), Color3.fromRGB(68, 48, 30), Enum.Material.WoodPlanks)
	woodFace.CFrame = handle.CFrame * CFrame.new(0, 0, 0)
	addMesh(woodFace, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.35))
	weldParts(handle, woodFace)

	-- Outer Forged Iron Band Rim
	local ironRim = makePart(shield, "ShieldIronRim", Vector3.new(2.78, 2.78, 0.22), Color3.fromRGB(48, 52, 60), Enum.Material.Metal)
	ironRim.CFrame = handle.CFrame * CFrame.new(0, 0, 0.01)
	addMesh(ironRim, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.28))
	weldParts(handle, ironRim)

	-- 8 Perimeter Brass Rivets
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local r = 1.28
		local rx = math.cos(angle) * r
		local ry = math.sin(angle) * r
		local rivet = makePart(shield, "RimRivet_" .. i, Vector3.new(0.15, 0.15, 0.26), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
		rivet.CFrame = handle.CFrame * CFrame.new(rx, ry, 0.03)
		addMesh(rivet, Enum.MeshType.Sphere, Vector3.new(0.9, 0.9, 0.6))
		weldParts(handle, rivet)
	end

	-- Reinforcement Steel Cross Straps
	local vertStrap = makePart(shield, "VertStrap", Vector3.new(0.22, 2.6, 0.24), Color3.fromRGB(52, 57, 66), Enum.Material.Metal)
	vertStrap.CFrame = handle.CFrame * CFrame.new(0, 0, 0.02)
	weldParts(handle, vertStrap)

	local horizStrap = makePart(shield, "HorizStrap", Vector3.new(2.6, 0.22, 0.24), Color3.fromRGB(52, 57, 66), Enum.Material.Metal)
	horizStrap.CFrame = handle.CFrame * CFrame.new(0, 0, 0.02)
	weldParts(handle, horizStrap)

	-- Central Boss Base & Pointed Umbo
	local bossBase = makePart(shield, "BossBase", Vector3.new(0.95, 0.95, 0.30), Color3.fromRGB(188, 145, 55), Enum.Material.Metal)
	bossBase.CFrame = handle.CFrame * CFrame.new(0, 0, 0.07) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(bossBase, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.5))
	weldParts(handle, bossBase)

	local bossDome = makePart(shield, "BossDome", Vector3.new(0.68, 0.68, 0.40), Color3.fromRGB(50, 55, 64), Enum.Material.Metal)
	bossDome.CFrame = handle.CFrame * CFrame.new(0, 0, 0.12)
	addMesh(bossDome, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.85))
	weldParts(handle, bossDome)

	local bossPoint = makePart(shield, "BossPoint", Vector3.new(0.20, 0.20, 0.24), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
	bossPoint.CFrame = handle.CFrame * CFrame.new(0, 0, 0.25)
	addMesh(bossPoint, Enum.MeshType.Pyramid)
	weldParts(handle, bossPoint)

	return shield, handle
end

-- ============================================================================
-- 2. SUNFORGED RELIC SET (Tier 3 Legendary Holy Gear - Ready for Crafting)
-- ============================================================================

local function createSunforgedSwordModel(): (Model, BasePart, Trail)
	local sword = Instance.new("Model")
	sword.Name = "EquippedSword"

	-- Handle / Grip Root
	local handle = makePart(sword, "Handle", Vector3.new(0.32, 1.2, 0.32), Color3.fromRGB(34, 26, 22), Enum.Material.Wood)
	sword.PrimaryPart = handle

	-- Grip Wrapping Bands (Gold Filigree Rings)
	for i = -1, 1 do
		local ring = makePart(sword, "GripRing_" .. i, Vector3.new(0.36, 0.08, 0.36), Color3.fromRGB(240, 195, 60), Enum.Material.Metal)
		ring.CFrame = handle.CFrame * CFrame.new(0, i * 0.28, 0)
		addMesh(ring, Enum.MeshType.Sphere, Vector3.new(1.05, 0.4, 1.05))
		weldParts(handle, ring)
	end

	-- ── Pommel (Faceted Octagonal Gold Base + Embedded Soul-Gem) ──────────
	local pommelCollar = makePart(sword, "PommelCollar", Vector3.new(0.48, 0.15, 0.48), Color3.fromRGB(215, 170, 45), Enum.Material.Metal)
	pommelCollar.CFrame = handle.CFrame * CFrame.new(0, -0.65, 0)
	addMesh(pommelCollar, Enum.MeshType.Sphere, Vector3.new(1.0, 0.5, 1.0))
	weldParts(handle, pommelCollar)

	local pommelCore = makePart(sword, "PommelCore", Vector3.new(0.62, 0.42, 0.62), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	pommelCore.CFrame = handle.CFrame * CFrame.new(0, -0.85, 0) * CFrame.Angles(0, math.rad(45), 0)
	addMesh(pommelCore, Enum.MeshType.Sphere, Vector3.new(1.0, 0.8, 1.0))
	weldParts(handle, pommelCore)

	local pommelGem = makePart(sword, "PommelGem", Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(255, 190, 55), Enum.Material.Neon)
	pommelGem.CFrame = handle.CFrame * CFrame.new(0, -0.85, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	addMesh(pommelGem, Enum.MeshType.Sphere)
	weldParts(handle, pommelGem)

	local pommelSpike = makePart(sword, "PommelSpike", Vector3.new(0.28, 0.22, 0.28), Color3.fromRGB(215, 170, 45), Enum.Material.Metal)
	pommelSpike.CFrame = handle.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, math.rad(45), 0)
	addMesh(pommelSpike, Enum.MeshType.Pyramid)
	weldParts(handle, pommelSpike)

	local pommelLight = Instance.new("PointLight")
	pommelLight.Name = "PommelGlow"
	pommelLight.Color = Color3.fromRGB(255, 200, 70)
	pommelLight.Range = 4
	pommelLight.Brightness = 1.2
	pommelLight.Parent = pommelGem

	-- ── Crossguard (Majestic Winged Quillons + Guard Crest) ────────────────
	local guardCenter = makePart(sword, "CrossguardCenter", Vector3.new(0.85, 0.42, 0.70), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	guardCenter.CFrame = handle.CFrame * CFrame.new(0, 0.72, 0)
	addMesh(guardCenter, Enum.MeshType.Torso, Vector3.new(1.0, 0.8, 1.0))
	weldParts(handle, guardCenter)

	-- Left Quillon Wing
	local leftWing = makePart(sword, "LeftQuillonWing", Vector3.new(0.85, 0.30, 0.55), Color3.fromRGB(215, 170, 45), Enum.Material.Metal)
	leftWing.CFrame = handle.CFrame * CFrame.new(-0.85, 0.85, 0) * CFrame.Angles(0, 0, math.rad(-14))
	addMesh(leftWing, Enum.MeshType.Wedge)
	weldParts(handle, leftWing)

	local leftTip = makePart(sword, "LeftQuillonTip", Vector3.new(0.42, 0.38, 0.45), Color3.fromRGB(245, 205, 75), Enum.Material.Metal)
	leftTip.CFrame = handle.CFrame * CFrame.new(-1.42, 1.02, 0) * CFrame.Angles(0, 0, math.rad(-28))
	addMesh(leftTip, Enum.MeshType.Pyramid)
	weldParts(handle, leftTip)

	-- Right Quillon Wing
	local rightWing = makePart(sword, "RightQuillonWing", Vector3.new(0.85, 0.30, 0.55), Color3.fromRGB(215, 170, 45), Enum.Material.Metal)
	rightWing.CFrame = handle.CFrame * CFrame.new(0.85, 0.85, 0) * CFrame.Angles(0, 0, math.rad(14))
	addMesh(rightWing, Enum.MeshType.Wedge)
	weldParts(handle, rightWing)

	local rightTip = makePart(sword, "RightQuillonTip", Vector3.new(0.42, 0.38, 0.45), Color3.fromRGB(245, 205, 75), Enum.Material.Metal)
	rightTip.CFrame = handle.CFrame * CFrame.new(1.42, 1.02, 0) * CFrame.Angles(0, 0, math.rad(28))
	addMesh(rightTip, Enum.MeshType.Pyramid)
	weldParts(handle, rightTip)

	-- Center Guard Crest (Diamond Sun Seal on both faces)
	local guardCrestF = makePart(sword, "GuardCrestFront", Vector3.new(0.38, 0.38, 0.18), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	guardCrestF.CFrame = handle.CFrame * CFrame.new(0, 0.72, 0.38) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(guardCrestF, Enum.MeshType.Sphere)
	weldParts(handle, guardCrestF)

	local guardCrestB = makePart(sword, "GuardCrestBack", Vector3.new(0.38, 0.38, 0.18), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	guardCrestB.CFrame = handle.CFrame * CFrame.new(0, 0.72, -0.38) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(guardCrestB, Enum.MeshType.Sphere)
	weldParts(handle, guardCrestB)

	-- ── Ricasso (Fortified Blade Base) ────────────────────────────────────
	local ricasso = makePart(sword, "Ricasso", Vector3.new(0.72, 0.55, 0.52), Color3.fromRGB(48, 52, 64), Enum.Material.Metal)
	ricasso.CFrame = handle.CFrame * CFrame.new(0, 1.15, 0)
	weldParts(handle, ricasso)

	local ricassoCollar = makePart(sword, "RicassoCollar", Vector3.new(0.80, 0.14, 0.58), Color3.fromRGB(230, 185, 55), Enum.Material.Metal)
	ricassoCollar.CFrame = handle.CFrame * CFrame.new(0, 0.98, 0)
	weldParts(handle, ricassoCollar)

	-- ── Main Blade (Tempered Steel + Central Glowing Runic Fuller) ─────────
	local bladeSteel = makePart(sword, "BladeSteel", Vector3.new(0.84, 3.2, 0.22), Color3.fromRGB(225, 232, 245), Enum.Material.Metal)
	bladeSteel.CFrame = handle.CFrame * CFrame.new(0, 2.95, 0)
	weldParts(handle, bladeSteel)

	local bladeSpine = makePart(sword, "BladeSpine", Vector3.new(0.48, 3.2, 0.26), Color3.fromRGB(56, 60, 72), Enum.Material.Metal)
	bladeSpine.CFrame = handle.CFrame * CFrame.new(0, 2.95, 0)
	weldParts(handle, bladeSpine)

	-- Glowing Central Runic Fuller Groove (Holy Sunfire Channel)
	local runicFuller = makePart(sword, "RunicFuller", Vector3.new(0.22, 2.9, 0.30), Color3.fromRGB(255, 205, 65), Enum.Material.Neon)
	runicFuller.CFrame = handle.CFrame * CFrame.new(0, 2.95, 0)
	weldParts(handle, runicFuller)

	-- 3 Floating Inscribed Rune Nodes along the fuller
	local runeOffsets = {2.0, 2.95, 3.9}
	local runeSizes = {0.32, 0.28, 0.24}
	for idx, yOff in ipairs(runeOffsets) do
		local sz = runeSizes[idx]
		local rune = makePart(sword, "RuneGlyph_" .. idx, Vector3.new(sz, sz, 0.34), Color3.fromRGB(255, 235, 120), Enum.Material.Neon)
		rune.CFrame = handle.CFrame * CFrame.new(0, yOff, 0) * CFrame.Angles(0, 0, math.rad(45))
		weldParts(handle, rune)
	end

	-- Lower Edge Gilded Inlays
	local leftInlay = makePart(sword, "LeftInlay", Vector3.new(0.08, 1.2, 0.25), Color3.fromRGB(230, 185, 55), Enum.Material.Metal)
	leftInlay.CFrame = handle.CFrame * CFrame.new(-0.42, 2.05, 0)
	weldParts(handle, leftInlay)

	local rightInlay = makePart(sword, "RightInlay", Vector3.new(0.08, 1.2, 0.25), Color3.fromRGB(230, 185, 55), Enum.Material.Metal)
	rightInlay.CFrame = handle.CFrame * CFrame.new(0.42, 2.05, 0)
	weldParts(handle, rightInlay)

	-- ── Tapered Blade Tip ─────────────────────────────────────────────────
	local tipMid = makePart(sword, "BladeTipMid", Vector3.new(0.66, 0.65, 0.20), Color3.fromRGB(228, 235, 248), Enum.Material.Metal)
	tipMid.CFrame = handle.CFrame * CFrame.new(0, 4.8, 0)
	addMesh(tipMid, Enum.MeshType.Wedge)
	weldParts(handle, tipMid)

	local tipRune = makePart(sword, "BladeTipRune", Vector3.new(0.18, 0.45, 0.24), Color3.fromRGB(255, 215, 80), Enum.Material.Neon)
	tipRune.CFrame = handle.CFrame * CFrame.new(0, 4.75, 0)
	weldParts(handle, tipRune)

	local tipPoint = makePart(sword, "BladeTipPoint", Vector3.new(0.36, 0.55, 0.16), Color3.fromRGB(240, 246, 255), Enum.Material.Metal)
	tipPoint.CFrame = handle.CFrame * CFrame.new(0, 5.3, 0)
	addMesh(tipPoint, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.7))
	weldParts(handle, tipPoint)

	-- Blade Aura Glow
	local bladeLight = Instance.new("PointLight")
	bladeLight.Name = "BladeAuraGlow"
	bladeLight.Color = Color3.fromRGB(255, 215, 85)
	bladeLight.Range = 8
	bladeLight.Brightness = 1.4
	bladeLight.Parent = runicFuller

	-- Sacred Embers Particle Emitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SacredEmbers"
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 185, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 20)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.75)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(0.4, 0.9)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Enabled = true
	emitter.Parent = runicFuller

	-- ── Sword Trail Attachments ───────────────────────────────────────────
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 0.8, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 5.5, 0)
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 220)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 215, 75)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 140, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 40, 10)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.25
	trail.Enabled = false
	trail.Parent = handle

	return sword, handle, trail
end

local function createSunforgedShieldModel(): (Model, BasePart)
	local shield = Instance.new("Model")
	shield.Name = "EquippedShield"

	-- Handle / Attachment root (transparent mounting block)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = shield
	shield.PrimaryPart = handle

	-- ── Authentic Backside Forearm Mount & Grip ───────────────────────────
	local innerPad = makePart(shield, "ShieldInnerPad", Vector3.new(1.9, 2.8, 0.10), Color3.fromRGB(26, 28, 36), Enum.Material.Fabric)
	innerPad.CFrame = handle.CFrame * CFrame.new(0, 0, -0.18)
	weldParts(handle, innerPad)

	local forearmBrace = makePart(shield, "ForearmBrace", Vector3.new(0.85, 0.45, 0.16), Color3.fromRGB(48, 34, 26), Enum.Material.Fabric)
	forearmBrace.CFrame = handle.CFrame * CFrame.new(-0.25, 0.65, -0.24)
	weldParts(handle, forearmBrace)

	local ironGripBar = makePart(shield, "IronGripBar", Vector3.new(0.18, 0.75, 0.18), Color3.fromRGB(85, 90, 102), Enum.Material.Metal)
	ironGripBar.CFrame = handle.CFrame * CFrame.new(0, -0.1, -0.26)
	weldParts(handle, ironGripBar)

	-- ── Main Tapered Kite Shield Body ─────────────────────────────────────
	local mainPlate = makePart(shield, "ShieldMainPlate", Vector3.new(2.5, 2.2, 0.32), Color3.fromRGB(34, 38, 48), Enum.Material.Metal)
	mainPlate.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0)
	weldParts(handle, mainPlate)

	local lowerTier1 = makePart(shield, "ShieldLowerTier1", Vector3.new(2.0, 1.0, 0.32), Color3.fromRGB(34, 38, 48), Enum.Material.Metal)
	lowerTier1.CFrame = handle.CFrame * CFrame.new(0, -1.2, 0)
	weldParts(handle, lowerTier1)

	local lowerTier2 = makePart(shield, "ShieldLowerTier2", Vector3.new(1.3, 0.8, 0.32), Color3.fromRGB(34, 38, 48), Enum.Material.Metal)
	lowerTier2.CFrame = handle.CFrame * CFrame.new(0, -1.95, 0)
	weldParts(handle, lowerTier2)

	local bottomSpike = makePart(shield, "ShieldBottomSpike", Vector3.new(0.65, 0.55, 0.35), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	bottomSpike.CFrame = handle.CFrame * CFrame.new(0, -2.48, 0)
	addMesh(bottomSpike, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
	weldParts(handle, bottomSpike)

	-- ── Upper Mantle / Crest Notches ──────────────────────────────────────
	local topCrownCenter = makePart(shield, "TopCrownCenter", Vector3.new(1.6, 0.38, 0.33), Color3.fromRGB(34, 38, 48), Enum.Material.Metal)
	topCrownCenter.CFrame = handle.CFrame * CFrame.new(0, 1.5, 0)
	weldParts(handle, topCrownCenter)

	local leftWingCrown = makePart(shield, "LeftWingCrown", Vector3.new(0.55, 0.52, 0.35), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	leftWingCrown.CFrame = handle.CFrame * CFrame.new(-1.12, 1.52, 0)
	addMesh(leftWingCrown, Enum.MeshType.Wedge)
	weldParts(handle, leftWingCrown)

	local rightWingCrown = makePart(shield, "RightWingCrown", Vector3.new(0.55, 0.52, 0.35), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	rightWingCrown.CFrame = handle.CFrame * CFrame.new(1.12, 1.52, 0)
	addMesh(rightWingCrown, Enum.MeshType.Wedge)
	weldParts(handle, rightWingCrown)

	-- ── Heavy Gilded Rim Framework ────────────────────────────────────────
	local leftRim = makePart(shield, "ShieldLeftRim", Vector3.new(0.24, 2.4, 0.38), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	leftRim.CFrame = handle.CFrame * CFrame.new(-1.32, 0.3, 0.02)
	weldParts(handle, leftRim)

	local rightRim = makePart(shield, "ShieldRightRim", Vector3.new(0.24, 2.4, 0.38), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	rightRim.CFrame = handle.CFrame * CFrame.new(1.32, 0.3, 0.02)
	weldParts(handle, rightRim)

	local topRim = makePart(shield, "ShieldTopRim", Vector3.new(2.7, 0.22, 0.38), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	topRim.CFrame = handle.CFrame * CFrame.new(0, 1.68, 0.02)
	weldParts(handle, topRim)

	local lowerLeftRim = makePart(shield, "ShieldLowerLeftRim", Vector3.new(0.24, 1.6, 0.38), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	lowerLeftRim.CFrame = handle.CFrame * CFrame.new(-0.85, -1.65, 0.02) * CFrame.Angles(0, 0, math.rad(22))
	weldParts(handle, lowerLeftRim)

	local lowerRightRim = makePart(shield, "ShieldLowerRightRim", Vector3.new(0.24, 1.6, 0.38), Color3.fromRGB(225, 180, 50), Enum.Material.Metal)
	lowerRightRim.CFrame = handle.CFrame * CFrame.new(0.85, -1.65, 0.02) * CFrame.Angles(0, 0, math.rad(-22))
	weldParts(handle, lowerRightRim)

	-- ── Heraldic Gilded Dividers (Cross & Quartering) ─────────────────────
	local vertSpine = makePart(shield, "ShieldVertSpine", Vector3.new(0.22, 3.5, 0.36), Color3.fromRGB(235, 190, 55), Enum.Material.Metal)
	vertSpine.CFrame = handle.CFrame * CFrame.new(0, -0.2, 0.03)
	weldParts(handle, vertSpine)

	local horizCross = makePart(shield, "ShieldHorizCross", Vector3.new(2.4, 0.22, 0.36), Color3.fromRGB(235, 190, 55), Enum.Material.Metal)
	horizCross.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.03)
	weldParts(handle, horizCross)

	-- ── Corner Rivets / Gilded Studs ──────────────────────────────────────
	local rivetCoords = {
		Vector3.new(-1.12, 1.42, 0.22),
		Vector3.new(1.12, 1.42, 0.22),
		Vector3.new(-1.18, -0.72, 0.22),
		Vector3.new(1.18, -0.72, 0.22),
		Vector3.new(0, 1.42, 0.22),
		Vector3.new(0, -1.95, 0.22),
	}
	for i, coord in ipairs(rivetCoords) do
		local rivet = makePart(shield, "Rivet_" .. i, Vector3.new(0.20, 0.20, 0.20), Color3.fromRGB(250, 210, 70), Enum.Material.Metal)
		rivet.CFrame = handle.CFrame * CFrame.new(coord) * CFrame.Angles(math.rad(45), math.rad(45), 0)
		addMesh(rivet, Enum.MeshType.Sphere, Vector3.new(0.9, 0.9, 0.6))
		weldParts(handle, rivet)
	end

	-- ── Ornate Central Boss & Glowing Aegis Soul Core ─────────────────────
	local bossMount = makePart(shield, "ShieldBossMount", Vector3.new(1.35, 1.35, 0.44), Color3.fromRGB(215, 170, 45), Enum.Material.Metal)
	bossMount.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.12) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(bossMount, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.6))
	weldParts(handle, bossMount)

	local innerCrest = makePart(shield, "ShieldInnerCrest", Vector3.new(1.02, 1.02, 0.50), Color3.fromRGB(240, 195, 60), Enum.Material.Metal)
	innerCrest.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.18) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(innerCrest, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.7))
	weldParts(handle, innerCrest)

	local soulCore = makePart(shield, "ShieldSoulCore", Vector3.new(0.68, 0.68, 0.58), Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
	soulCore.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.24) * CFrame.Angles(0, 0, math.rad(45))
	addMesh(soulCore, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.9))
	weldParts(handle, soulCore)

	local coreJewel = makePart(shield, "ShieldCoreJewel", Vector3.new(0.36, 0.36, 0.66), Color3.fromRGB(255, 240, 140), Enum.Material.Neon)
	coreJewel.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0.28) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	addMesh(coreJewel, Enum.MeshType.Sphere)
	weldParts(handle, coreJewel)

	local coreLight = Instance.new("PointLight")
	coreLight.Name = "ShieldCoreGlow"
	coreLight.Color = Color3.fromRGB(255, 200, 70)
	coreLight.Range = 8
	coreLight.Brightness = 2.2
	coreLight.Parent = coreJewel

	local shieldEmitter = Instance.new("ParticleEmitter")
	shieldEmitter.Name = "ShieldMotes"
	shieldEmitter.LightEmission = 1
	shieldEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 175, 45)),
	})
	shieldEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0),
	})
	shieldEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	shieldEmitter.Lifetime = NumberRange.new(0.5, 0.9)
	shieldEmitter.Rate = 3.0
	shieldEmitter.Speed = NumberRange.new(0.2, 0.6)
	shieldEmitter.SpreadAngle = Vector2.new(30, 30)
	shieldEmitter.Enabled = true
	shieldEmitter.Parent = soulCore

	return shield, handle
end

-- ============================================================================
-- 3. ROCKHIDE WARLORD SET (Tier 2 Rare — Boss Fragment Gear)
-- ============================================================================

local function createRockhideSwordModel(): (Model, BasePart, Trail)
	local sword = Instance.new("Model")
	sword.Name = "EquippedSword"

	-- Handle / Grip Root (rough wrapped reptile leather over stone tang)
	local handle = makePart(sword, "Handle", Vector3.new(0.36, 1.35, 0.36), Color3.fromRGB(48, 34, 22), Enum.Material.Fabric)
	sword.PrimaryPart = handle

	-- Leather & Iron Grip Collars
	for i = -1, 1 do
		local wrap = makePart(sword, "WrapRing_" .. i, Vector3.new(0.40, 0.12, 0.40), Color3.fromRGB(80, 52, 28), Enum.Material.SmoothPlastic)
		wrap.CFrame = handle.CFrame * CFrame.new(0, i * 0.32, 0)
		addMesh(wrap, Enum.MeshType.Sphere, Vector3.new(1.1, 0.6, 1.1))
		weldParts(handle, wrap)

		local ironBand = makePart(sword, "IronBand_" .. i, Vector3.new(0.42, 0.05, 0.42), Color3.fromRGB(68, 62, 58), Enum.Material.Metal)
		ironBand.CFrame = handle.CFrame * CFrame.new(0, i * 0.32, 0)
		weldParts(handle, ironBand)
	end

	-- ── Pommel (Heavy Carved Basalt Wheel Pommel with 4 Barbs) ─────────────
	local pommel = makePart(sword, "Pommel", Vector3.new(0.76, 0.42, 0.76), Color3.fromRGB(44, 40, 36), Enum.Material.Slate)
	pommel.CFrame = handle.CFrame * CFrame.new(0, -0.92, 0)
	addMesh(pommel, Enum.MeshType.Sphere, Vector3.new(1.1, 0.65, 1.1))
	weldParts(handle, pommel)

	-- 4 Protruding stone pommel spikes
	for _, rot in {0, 90, 180, 270} do
		local pSpike = makePart(sword, "PommelSpike_" .. rot, Vector3.new(0.18, 0.22, 0.18), Color3.fromRGB(34, 30, 28), Enum.Material.Slate)
		local rad = math.rad(rot)
		pSpike.CFrame = handle.CFrame * CFrame.new(math.cos(rad) * 0.38, -0.92, math.sin(rad) * 0.38) * CFrame.Angles(0, rad, math.rad(90))
		addMesh(pSpike, Enum.MeshType.Pyramid)
		weldParts(handle, pSpike)
	end

	local pommelGem = makePart(sword, "PommelEmber", Vector3.new(0.36, 0.36, 0.36), Color3.fromRGB(255, 105, 25), Enum.Material.Neon)
	pommelGem.CFrame = handle.CFrame * CFrame.new(0, -0.92, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	addMesh(pommelGem, Enum.MeshType.Sphere)
	weldParts(handle, pommelGem)

	local pommelLight = Instance.new("PointLight")
	pommelLight.Name = "EmberGlow"
	pommelLight.Color = Color3.fromRGB(255, 110, 30)
	pommelLight.Range = 6
	pommelLight.Brightness = 1.2
	pommelLight.Parent = pommelGem

	-- ── Crossguard (Swept Wyvern Horn Quillons & Magma Demon Eye) ─────────
	local guardCenter = makePart(sword, "CrossguardCenter", Vector3.new(0.92, 0.52, 0.72), Color3.fromRGB(48, 44, 40), Enum.Material.Cobblestone)
	guardCenter.CFrame = handle.CFrame * CFrame.new(0, 0.82, 0)
	addMesh(guardCenter, Enum.MeshType.Sphere, Vector3.new(1.1, 0.85, 1.0))
	weldParts(handle, guardCenter)

	-- Left Swept-Forward Wyvern Horn Quillon
	local leftQ = makePart(sword, "LeftQuillon", Vector3.new(1.25, 0.38, 0.52), Color3.fromRGB(56, 50, 44), Enum.Material.Cobblestone)
	leftQ.CFrame = handle.CFrame * CFrame.new(-0.85, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-14))
	addMesh(leftQ, Enum.MeshType.Wedge)
	weldParts(handle, leftQ)

	local leftQTip = makePart(sword, "LeftQuillonTip", Vector3.new(0.40, 0.55, 0.40), Color3.fromRGB(38, 34, 30), Enum.Material.Slate)
	leftQTip.CFrame = handle.CFrame * CFrame.new(-1.62, 1.18, 0) * CFrame.Angles(0, 0, math.rad(-25))
	addMesh(leftQTip, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
	weldParts(handle, leftQTip)

	-- Right Swept-Forward Wyvern Horn Quillon
	local rightQ = makePart(sword, "RightQuillon", Vector3.new(1.25, 0.38, 0.52), Color3.fromRGB(56, 50, 44), Enum.Material.Cobblestone)
	rightQ.CFrame = handle.CFrame * CFrame.new(0.85, 0.95, 0) * CFrame.Angles(0, 0, math.rad(14))
	addMesh(rightQ, Enum.MeshType.Wedge)
	weldParts(handle, rightQ)

	local rightQTip = makePart(sword, "RightQuillonTip", Vector3.new(0.40, 0.55, 0.40), Color3.fromRGB(38, 34, 30), Enum.Material.Slate)
	rightQTip.CFrame = handle.CFrame * CFrame.new(1.62, 1.18, 0) * CFrame.Angles(0, 0, math.rad(25))
	addMesh(rightQTip, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
	weldParts(handle, rightQTip)

	-- Center Magma Demon Eye in Guard
	local guardEmber = makePart(sword, "GuardEmber", Vector3.new(0.42, 0.42, 0.28), Color3.fromRGB(255, 120, 20), Enum.Material.Neon)
	guardEmber.CFrame = handle.CFrame * CFrame.new(0, 0.82, 0.38)
	addMesh(guardEmber, Enum.MeshType.Sphere)
	weldParts(handle, guardEmber)

	local guardLight = Instance.new("PointLight")
	guardLight.Name = "GuardEmberGlow"
	guardLight.Color = Color3.fromRGB(255, 120, 20)
	guardLight.Range = 7
	guardLight.Brightness = 1.4
	guardLight.Parent = guardEmber

	-- ── Colossal Wyvern Cleaver Blade ──────────────────────────────────────
	local bladeBase = makePart(sword, "BladeBase", Vector3.new(0.95, 0.70, 0.28), Color3.fromRGB(38, 36, 34), Enum.Material.Slate)
	bladeBase.CFrame = handle.CFrame * CFrame.new(0, 1.30, 0)
	addMesh(bladeBase, Enum.MeshType.Torso, Vector3.new(1.05, 1.0, 0.9))
	weldParts(handle, bladeBase)

	local bladeMain = makePart(sword, "BladeMain", Vector3.new(1.02, 3.2, 0.26), Color3.fromRGB(48, 45, 42), Enum.Material.Slate)
	bladeMain.CFrame = handle.CFrame * CFrame.new(0, 3.05, 0)
	weldParts(handle, bladeMain)

	local bladeEdge = makePart(sword, "BladeEdge", Vector3.new(0.72, 3.1, 0.30), Color3.fromRGB(32, 30, 28), Enum.Material.SmoothPlastic)
	bladeEdge.CFrame = handle.CFrame * CFrame.new(0, 3.0, 0)
	addMesh(bladeEdge, Enum.MeshType.Wedge)
	weldParts(handle, bladeEdge)

	-- 4 Jagged Serrated Dragon Spine Teeth along dorsal edge
	local spineOffsets = {1.8, 2.4, 3.0, 3.6}
	for i, yPos in ipairs(spineOffsets) do
		local spineTooth = makePart(sword, "SpineTooth_" .. i, Vector3.new(0.26, 0.32, 0.28), Color3.fromRGB(32, 28, 26), Enum.Material.Slate)
		spineTooth.CFrame = handle.CFrame * CFrame.new(0.56, yPos, 0) * CFrame.Angles(0, 0, math.rad(28))
		addMesh(spineTooth, Enum.MeshType.Pyramid, Vector3.new(0.85, 1.2, 0.85))
		weldParts(handle, spineTooth)
	end

	-- Glowing Branching Seismic Magma Fissures
	local crackA = makePart(sword, "CrackA", Vector3.new(0.18, 2.2, 0.28), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
	crackA.CFrame = handle.CFrame * CFrame.new(-0.18, 2.65, 0) * CFrame.Angles(0, 0, math.rad(6))
	addMesh(crackA, Enum.MeshType.Sphere, Vector3.new(0.7, 1.0, 0.5))
	weldParts(handle, crackA)

	local crackB = makePart(sword, "CrackB", Vector3.new(0.14, 1.5, 0.28), Color3.fromRGB(255, 80, 15), Enum.Material.Neon)
	crackB.CFrame = handle.CFrame * CFrame.new(0.22, 3.0, 0) * CFrame.Angles(0, 0, math.rad(-8))
	addMesh(crackB, Enum.MeshType.Sphere, Vector3.new(0.7, 1.0, 0.5))
	weldParts(handle, crackB)

	local bladeGlow = Instance.new("PointLight")
	bladeGlow.Name = "BladeEmberGlow"
	bladeGlow.Color = Color3.fromRGB(255, 105, 20)
	bladeGlow.Range = 8
	bladeGlow.Brightness = 1.2
	bladeGlow.Parent = crackA

	-- ── Chisel Cleaver Tip ────────────────────────────────────────────────
	local tipBody = makePart(sword, "BladeTip", Vector3.new(0.75, 0.72, 0.24), Color3.fromRGB(38, 36, 34), Enum.Material.Slate)
	tipBody.CFrame = handle.CFrame * CFrame.new(0, 4.85, 0)
	addMesh(tipBody, Enum.MeshType.Wedge)
	weldParts(handle, tipBody)

	local tipPoint = makePart(sword, "BladeTipPoint", Vector3.new(0.40, 0.65, 0.22), Color3.fromRGB(30, 28, 26), Enum.Material.Slate)
	tipPoint.CFrame = handle.CFrame * CFrame.new(0, 5.40, 0)
	addMesh(tipPoint, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.4, 0.8))
	weldParts(handle, tipPoint)

	-- Ember particle emitter on blade
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SeismicEmbers"
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 5)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(0.3, 0.9)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Enabled = true
	emitter.Parent = crackA

	-- ── Sword Trail (Blazing Molten Trail) ─────────────────────────────────
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 0.8, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 5.5, 0)
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 120, 25)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(180, 45, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 15, 5)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.25
	trail.Enabled = false
	trail.Parent = handle

	return sword, handle, trail
end

local function createRockhideShieldModel(): (Model, BasePart)
	local shield = Instance.new("Model")
	shield.Name = "EquippedShield"

	-- Handle (invisible mounting root aligned with left hand grip)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = shield
	shield.PrimaryPart = handle

	-- ── Authentic Backside Forearm Mount & Leather Grip (-Z side, facing arm) ──
	local innerBacking = makePart(shield, "ShieldInnerBacking", Vector3.new(2.8, 2.8, 0.12), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
	innerBacking.CFrame = handle.CFrame * CFrame.new(0, 0, -0.12)
	addMesh(innerBacking, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.35))
	weldParts(handle, innerBacking)

	local forearmStrap = makePart(shield, "ForearmStrap", Vector3.new(0.85, 0.40, 0.14), Color3.fromRGB(48, 34, 24), Enum.Material.Fabric)
	forearmStrap.CFrame = handle.CFrame * CFrame.new(-0.25, 0.50, -0.20)
	weldParts(handle, forearmStrap)

	local gripBar = makePart(shield, "GripBar", Vector3.new(0.18, 0.70, 0.18), Color3.fromRGB(50, 55, 64), Enum.Material.Metal)
	gripBar.CFrame = handle.CFrame * CFrame.new(0, -0.10, -0.22)
	weldParts(handle, gripBar)

	-- ── Main Circular Stone Shield Body (Core at Z = 0) ───────────────────
	local shieldBody = makePart(shield, "ShieldBody", Vector3.new(3.6, 3.6, 0.36), Color3.fromRGB(55, 50, 46), Enum.Material.Cobblestone)
	shieldBody.CFrame = handle.CFrame * CFrame.new(0, 0, 0)
	addMesh(shieldBody, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.45))
	weldParts(handle, shieldBody)

	-- Stone outer rim (slightly larger dark ring)
	local rimOuter = makePart(shield, "RimOuter", Vector3.new(3.85, 3.85, 0.26), Color3.fromRGB(40, 36, 32), Enum.Material.Slate)
	rimOuter.CFrame = handle.CFrame * CFrame.new(0, 0, 0.04)
	addMesh(rimOuter, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.35))
	weldParts(handle, rimOuter)

	-- Iron reinforcement outer band
	local rimIron = makePart(shield, "RimIron", Vector3.new(3.95, 3.95, 0.20), Color3.fromRGB(68, 65, 60), Enum.Material.Metal)
	rimIron.CFrame = handle.CFrame * CFrame.new(0, 0, 0.08)
	addMesh(rimIron, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.28))
	weldParts(handle, rimIron)

	-- ── 8 Heavy Forged Iron Rim Rivets (Securely set on the iron rim at r = 1.75) ──
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local r = 1.75
		local rx = math.cos(angle) * r
		local ry = math.sin(angle) * r
		local rivet = makePart(shield, "RimRivet_" .. i, Vector3.new(0.20, 0.20, 0.16), Color3.fromRGB(78, 74, 70), Enum.Material.Metal)
		rivet.CFrame = handle.CFrame * CFrame.new(rx, ry, 0.12)
		addMesh(rivet, Enum.MeshType.Sphere, Vector3.new(0.9, 0.9, 0.6))
		weldParts(handle, rivet)
	end

	-- ── Seismic Ember Crack Veins (+Z outward face, Neon orange glowing) ──
	-- 6 radial cracks emanating from center
	local crackAngles = {0, 60, 120, 180, 240, 300}
	for i, angle in ipairs(crackAngles) do
		local rad = math.rad(angle)
		local offsetX = math.cos(rad) * 1.05
		local offsetY = math.sin(rad) * 1.05
		local crack = makePart(shield, "EmberCrack_" .. i, Vector3.new(0.10, 1.4, 0.14), Color3.fromRGB(255, 100, 25), Enum.Material.Neon)
		crack.CFrame = handle.CFrame * CFrame.new(offsetX, offsetY, 0.10) * CFrame.Angles(0, 0, rad + math.rad(90))
		addMesh(crack, Enum.MeshType.Sphere, Vector3.new(0.6, 1.0, 0.5))
		weldParts(handle, crack)
	end

	-- 6 shorter secondary cracks between the main ones
	local diagCracks = {30, 90, 150, 210, 270, 330}
	for i, angle in ipairs(diagCracks) do
		local rad = math.rad(angle)
		local offsetX = math.cos(rad) * 0.75
		local offsetY = math.sin(rad) * 0.75
		local shortCrack = makePart(shield, "ShortCrack_" .. i, Vector3.new(0.08, 0.80, 0.14), Color3.fromRGB(255, 70, 15), Enum.Material.Neon)
		shortCrack.CFrame = handle.CFrame * CFrame.new(offsetX, offsetY, 0.11) * CFrame.Angles(0, 0, rad + math.rad(90))
		addMesh(shortCrack, Enum.MeshType.Sphere, Vector3.new(0.6, 1.0, 0.5))
		weldParts(handle, shortCrack)
	end

	-- ── Central Boss Dome (Rockhide Ember Eye, protruding forward at +Z) ──
	local bossDomeOuter = makePart(shield, "BossDomeOuter", Vector3.new(1.20, 1.20, 0.36), Color3.fromRGB(42, 38, 34), Enum.Material.Cobblestone)
	bossDomeOuter.CFrame = handle.CFrame * CFrame.new(0, 0, 0.16)
	addMesh(bossDomeOuter, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.75))
	weldParts(handle, bossDomeOuter)

	local bossDomeMid = makePart(shield, "BossDomeMid", Vector3.new(0.92, 0.92, 0.38), Color3.fromRGB(55, 48, 42), Enum.Material.Slate)
	bossDomeMid.CFrame = handle.CFrame * CFrame.new(0, 0, 0.24)
	addMesh(bossDomeMid, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.85))
	weldParts(handle, bossDomeMid)

	local bossDomeCore = makePart(shield, "BossDomeCore", Vector3.new(0.60, 0.60, 0.40), Color3.fromRGB(255, 100, 25), Enum.Material.Neon)
	bossDomeCore.CFrame = handle.CFrame * CFrame.new(0, 0, 0.32)
	addMesh(bossDomeCore, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 1.0))
	weldParts(handle, bossDomeCore)

	local bossDomeGlow = Instance.new("PointLight")
	bossDomeGlow.Name = "BossDomeEmberGlow"
	bossDomeGlow.Color = Color3.fromRGB(255, 110, 30)
	bossDomeGlow.Range = 10
	bossDomeGlow.Brightness = 1.4
	bossDomeGlow.Parent = bossDomeCore

	-- 5 Wyvern Rock Horn Spikes around the boss dome (protruding forward & outward)
	local spikeAngles = {0, 72, 144, 216, 288}
	for i, angle in ipairs(spikeAngles) do
		local rad = math.rad(angle)
		local spX = math.cos(rad) * 0.90
		local spY = math.sin(rad) * 0.90
		local spike = makePart(shield, "RockSpike_" .. i, Vector3.new(0.28, 0.42, 0.28), Color3.fromRGB(38, 34, 30), Enum.Material.Slate)
		spike.CFrame = handle.CFrame * CFrame.new(spX, spY, 0.22) * CFrame.Angles(0, 0, rad - math.rad(90)) * CFrame.Angles(math.rad(18), 0, 0)
		addMesh(spike, Enum.MeshType.Pyramid, Vector3.new(0.85, 1.3, 0.85))
		weldParts(handle, spike)
	end

	-- ── Ember Particle Emitter on boss dome (emitting forward) ────────────
	local shieldEmitter = Instance.new("ParticleEmitter")
	shieldEmitter.Name = "BossDomeEmbers"
	shieldEmitter.LightEmission = 1
	shieldEmitter.EmissionDirection = Enum.NormalId.Front
	shieldEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 5)),
	})
	shieldEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.10),
		NumberSequenceKeypoint.new(1, 0),
	})
	shieldEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	shieldEmitter.Lifetime = NumberRange.new(0.3, 0.6)
	shieldEmitter.Rate = 3
	shieldEmitter.Speed = NumberRange.new(0.3, 0.8)
	shieldEmitter.SpreadAngle = Vector2.new(30, 30)
	shieldEmitter.Enabled = true
	shieldEmitter.Parent = bossDomeCore

	return shield, handle
end


-- ============================================================================
-- 4. MAGE FOCUS STAVES (Apprentice & Rockhide Earthcaller)
-- ============================================================================

local function createApprenticeStaffModel(): (Model, BasePart, Trail)
	local staff = Instance.new("Model")
	staff.Name = "EquippedSword"

	-- Handle / Grip Root (where RightHand grips)
	local handle = makePart(staff, "Handle", Vector3.new(0.25, 1.20, 0.25), Color3.fromRGB(58, 40, 26), Enum.Material.Wood)
	staff.PrimaryPart = handle

	-- Lower Shaft Extension (-Y from grip)
	local lowerShaft = makePart(staff, "LowerShaft", Vector3.new(0.24, 2.0, 0.24), Color3.fromRGB(52, 36, 24), Enum.Material.Wood)
	lowerShaft.CFrame = handle.CFrame * CFrame.new(0, -1.5, 0)
	weldParts(handle, lowerShaft)

	-- Base Brass Foot Cap
	local baseCap = makePart(staff, "BaseCap", Vector3.new(0.28, 0.35, 0.28), Color3.fromRGB(195, 150, 50), Enum.Material.Metal)
	baseCap.CFrame = handle.CFrame * CFrame.new(0, -2.55, 0)
	addMesh(baseCap, Enum.MeshType.Sphere, Vector3.new(1.0, 0.7, 1.0))
	weldParts(handle, baseCap)

	-- Upper Shaft Extension (+Y from grip)
	local upperShaft = makePart(staff, "UpperShaft", Vector3.new(0.24, 2.2, 0.24), Color3.fromRGB(52, 36, 24), Enum.Material.Wood)
	upperShaft.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
	weldParts(handle, upperShaft)

	-- Polished Brass Rings along shaft
	for _, yOffset in {-0.7, 0.7, 2.2} do
		local ring = makePart(staff, "BrassRing", Vector3.new(0.32, 0.12, 0.32), Color3.fromRGB(205, 160, 55), Enum.Material.Metal)
		ring.CFrame = handle.CFrame * CFrame.new(0, yOffset, 0)
		addMesh(ring, Enum.MeshType.Cylinder)
		weldParts(handle, ring)
	end

	-- Ornate Brass Crown Prongs at the tip (+Y 2.8)
	local crownBase = makePart(staff, "CrownBase", Vector3.new(0.38, 0.25, 0.38), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
	crownBase.CFrame = handle.CFrame * CFrame.new(0, 2.75, 0)
	addMesh(crownBase, Enum.MeshType.Sphere, Vector3.new(1.0, 0.6, 1.0))
	weldParts(handle, crownBase)

	for _, angle in {0, 90, 180, 270} do
		local rad = math.rad(angle)
		local prong = makePart(staff, "Prong_" .. angle, Vector3.new(0.12, 0.65, 0.12), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
		prong.CFrame = handle.CFrame * CFrame.new(math.cos(rad) * 0.28, 3.05, math.sin(rad) * 0.28) * CFrame.Angles(math.sin(rad) * 0.2, 0, -math.cos(rad) * 0.2)
		addMesh(prong, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.2, 0.8))
		weldParts(handle, prong)
	end

	-- Floating Luminous Arcane Focus Crystal
	local crystal = makePart(staff, "FocusCrystal", Vector3.new(0.55, 0.85, 0.55), Color3.fromRGB(185, 80, 255), Enum.Material.Neon)
	crystal.CFrame = handle.CFrame * CFrame.new(0, 3.25, 0)
	addMesh(crystal, Enum.MeshType.Sphere, Vector3.new(0.7, 1.3, 0.7))
	weldParts(handle, crystal)

	-- Arcane Light Source
	local light = Instance.new("PointLight")
	light.Name = "ArcaneLight"
	light.Color = Color3.fromRGB(195, 110, 255)
	light.Brightness = 2.5
	light.Range = 10
	light.Parent = crystal

	-- Arcane Spark Emitter
	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "ArcaneMotes"
	sparkEmitter.LightEmission = 1
	sparkEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 50, 255)),
	})
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkEmitter.Lifetime = NumberRange.new(0.4, 0.8)
	sparkEmitter.Rate = 4
	sparkEmitter.Speed = NumberRange.new(0.3, 0.8)
	sparkEmitter.Parent = crystal

	-- Arcane Swing Trail
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 3.65, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 2.75, 0)
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "StaffTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 75, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 140)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.25
	trail.Enabled = false
	trail.Parent = handle

	return staff, handle, trail
end

local function createRockhideStaffModel(): (Model, BasePart, Trail)
	local staff = Instance.new("Model")
	staff.Name = "EquippedSword"

	-- Handle / Grip Root
	local handle = makePart(staff, "Handle", Vector3.new(0.32, 1.30, 0.32), Color3.fromRGB(44, 32, 22), Enum.Material.Wood)
	staff.PrimaryPart = handle

	-- Lower Gnarled Petrified Shaft
	local lowerShaft = makePart(staff, "LowerShaft", Vector3.new(0.30, 2.2, 0.30), Color3.fromRGB(36, 28, 22), Enum.Material.Slate)
	lowerShaft.CFrame = handle.CFrame * CFrame.new(0, -1.6, 0)
	weldParts(handle, lowerShaft)

	-- Basalt Claw Foot
	local baseSpur = makePart(staff, "BaseSpur", Vector3.new(0.42, 0.50, 0.42), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
	baseSpur.CFrame = handle.CFrame * CFrame.new(0, -2.8, 0)
	addMesh(baseSpur, Enum.MeshType.Pyramid, Vector3.new(1.0, 1.2, 1.0))
	weldParts(handle, baseSpur)

	-- Upper Shaft with Carved Volcanic Rock Plates
	local upperShaft = makePart(staff, "UpperShaft", Vector3.new(0.30, 2.4, 0.30), Color3.fromRGB(36, 28, 22), Enum.Material.Slate)
	upperShaft.CFrame = handle.CFrame * CFrame.new(0, 1.8, 0)
	weldParts(handle, upperShaft)

	-- Volcanic Slate Bands & Magma Vein Inlays
	for _, yOffset in {-0.8, 0.8, 2.4} do
		local band = makePart(staff, "RockBand", Vector3.new(0.46, 0.16, 0.46), Color3.fromRGB(48, 42, 38), Enum.Material.Cobblestone)
		band.CFrame = handle.CFrame * CFrame.new(0, yOffset, 0)
		addMesh(band, Enum.MeshType.Sphere, Vector3.new(1.1, 0.7, 1.1))
		weldParts(handle, band)

		local vein = makePart(staff, "Vein", Vector3.new(0.48, 0.08, 0.48), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
		vein.CFrame = handle.CFrame * CFrame.new(0, yOffset, 0)
		addMesh(vein, Enum.MeshType.Sphere, Vector3.new(1.05, 0.4, 1.05))
		weldParts(handle, vein)
	end

	-- Basalt Claw Crown (4 curved volcanic rock prongs)
	for _, rot in {0, 90, 180, 270} do
		local rad = math.rad(rot)
		local claw = makePart(staff, "Claw_" .. rot, Vector3.new(0.18, 0.85, 0.22), Color3.fromRGB(30, 26, 22), Enum.Material.Slate)
		claw.CFrame = handle.CFrame * CFrame.new(math.cos(rad) * 0.38, 3.25, math.sin(rad) * 0.38) * CFrame.Angles(math.sin(rad) * 0.25, 0, -math.cos(rad) * 0.25)
		addMesh(claw, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.3, 0.8))
		weldParts(handle, claw)
	end

	-- Incandescent Molten Magma Core
	local magmaCore = makePart(staff, "MagmaCore", Vector3.new(0.70, 0.70, 0.70), Color3.fromRGB(255, 100, 25), Enum.Material.Neon)
	magmaCore.CFrame = handle.CFrame * CFrame.new(0, 3.45, 0)
	addMesh(magmaCore, Enum.MeshType.Sphere)
	weldParts(handle, magmaCore)

	local fireLight = Instance.new("PointLight")
	fireLight.Name = "MagmaLight"
	fireLight.Color = Color3.fromRGB(255, 120, 30)
	fireLight.Brightness = 3.0
	fireLight.Range = 12
	fireLight.Parent = magmaCore

	local emberEmitter = Instance.new("ParticleEmitter")
	emberEmitter.Name = "MagmaEmbers"
	emberEmitter.LightEmission = 1
	emberEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 90, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 5)),
	})
	emberEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	emberEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emberEmitter.Lifetime = NumberRange.new(0.5, 1.0)
	emberEmitter.Rate = 5
	emberEmitter.Speed = NumberRange.new(0.4, 1.2)
	emberEmitter.Parent = magmaCore

	-- Magma Swing Trail
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 3.9, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 2.9, 0)
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "StaffTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 110, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 15, 5)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.25
	trail.Enabled = false
	trail.Parent = handle

	return staff, handle, trail
end

-- ============================================================================
-- 5. EQUIPMENT MODEL DISPATCHERS & VISUAL ATTACHMENTS
-- ============================================================================

local function createWeaponModel(weaponId: string?): (Model, BasePart, Trail)
	if weaponId == "ApprenticeStaff" then
		return createApprenticeStaffModel()
	elseif weaponId == "RockhideStaff" then
		return createRockhideStaffModel()
	elseif weaponId == "RockhideFang" or weaponId == "Rockhide" then
		return createRockhideSwordModel()
	else
		return createStandardSwordModel()
	end
end

local createSwordModel = createWeaponModel -- compatibility alias

local function createShieldModel(armsId: string?, weaponId: string?): (Model?, BasePart?)
	-- Mages and staff wielders do not carry heavy shields
	if weaponId == "ApprenticeStaff" or weaponId == "RockhideStaff" then
		return nil, nil
	end
	if armsId == "ApprenticeBracers" or armsId == "RockhideWraps" then
		return nil, nil
	end

	if armsId == "RockhideArms" or armsId == "Rockhide" then
		return createRockhideShieldModel()
	else
		return createStandardShieldModel()
	end
end

local function attachHelm(character: Model, helmId: string?)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local existing = character:FindFirstChild("EquippedHelm")
	if existing then existing:Destroy() end
	if not helmId then return end

	local helm = Instance.new("Model")
	helm.Name = "EquippedHelm"

	local isR15 = character:FindFirstChild("UpperTorso") ~= nil
	local hW = isR15 and 1.25 or 2.05
	local hH = isR15 and 1.15 or 1.05
	local hD = isR15 and 1.25 or 1.05

	if helmId == "RockhideHelm" then
		-- Monster Hunter Behemoth Horned Warhelm
		-- 1. Sculpted Volcanic Basalt Skullcap
		local skullCap = makePart(helm, "HelmDome", Vector3.new(hW * 1.04, 0.68, hD * 1.04), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
		skullCap.CFrame = head.CFrame * CFrame.new(0, hH * 0.36, 0)
		addMesh(skullCap, Enum.MeshType.Sphere, Vector3.new(1.02, 0.82, 1.02))
		weldParts(head, skullCap)

		-- 2. Heavy Carved Forehead Brow Band
		local brow = makePart(helm, "HelmBrow", Vector3.new(hW * 1.06, 0.26, hD * 1.06), Color3.fromRGB(44, 38, 32), Enum.Material.Cobblestone)
		brow.CFrame = head.CFrame * CFrame.new(0, hH * 0.14, 0)
		weldParts(head, brow)

		-- 3. Left Massive Sweeping Wyvern Horn (Segmented with Molten Tip & Outer Spur)
		local leftHorn = makePart(helm, "LeftHorn", Vector3.new(0.44, 1.25, 0.44), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
		leftHorn.CFrame = head.CFrame * CFrame.new(-hW * 0.58, hH * 0.58, -0.10) * CFrame.Angles(math.rad(22), 0, math.rad(-42))
		addMesh(leftHorn, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
		weldParts(head, leftHorn)

		local leftHornTip = makePart(helm, "LeftHornTip", Vector3.new(0.30, 0.82, 0.30), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
		leftHornTip.CFrame = head.CFrame * CFrame.new(-hW * 0.98, hH * 1.22, -0.24) * CFrame.Angles(math.rad(32), 0, math.rad(-55))
		addMesh(leftHornTip, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.4, 0.8))
		weldParts(head, leftHornTip)

		local leftHornSpur = makePart(helm, "LeftHornSpur", Vector3.new(0.22, 0.42, 0.22), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
		leftHornSpur.CFrame = head.CFrame * CFrame.new(-hW * 0.78, hH * 0.88, -0.05) * CFrame.Angles(math.rad(10), 0, math.rad(-75))
		addMesh(leftHornSpur, Enum.MeshType.Pyramid)
		weldParts(head, leftHornSpur)

		-- 4. Right Massive Sweeping Wyvern Horn (Segmented with Molten Tip & Outer Spur)
		local rightHorn = makePart(helm, "RightHorn", Vector3.new(0.44, 1.25, 0.44), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
		rightHorn.CFrame = head.CFrame * CFrame.new(hW * 0.58, hH * 0.58, -0.10) * CFrame.Angles(math.rad(22), 0, math.rad(42))
		addMesh(rightHorn, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
		weldParts(head, rightHorn)

		local rightHornTip = makePart(helm, "RightHornTip", Vector3.new(0.30, 0.82, 0.30), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
		rightHornTip.CFrame = head.CFrame * CFrame.new(hW * 0.98, hH * 1.22, -0.24) * CFrame.Angles(math.rad(32), 0, math.rad(55))
		addMesh(rightHornTip, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.4, 0.8))
		weldParts(head, rightHornTip)

		local rightHornSpur = makePart(helm, "RightHornSpur", Vector3.new(0.22, 0.42, 0.22), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
		rightHornSpur.CFrame = head.CFrame * CFrame.new(hW * 0.78, hH * 0.88, -0.05) * CFrame.Angles(math.rad(10), 0, math.rad(75))
		addMesh(rightHornSpur, Enum.MeshType.Pyramid)
		weldParts(head, rightHornSpur)

		-- 5. Forehead Rock Spikes (2 forward-facing hornlets)
		local leftSpike = makePart(helm, "LeftBrowSpike", Vector3.new(0.22, 0.42, 0.22), Color3.fromRGB(26, 22, 18), Enum.Material.Slate)
		leftSpike.CFrame = head.CFrame * CFrame.new(-hW * 0.34, hH * 0.30, -hD * 0.52) * CFrame.Angles(math.rad(-25), 0, math.rad(-15))
		addMesh(leftSpike, Enum.MeshType.Pyramid)
		weldParts(head, leftSpike)

		local rightSpike = makePart(helm, "RightBrowSpike", Vector3.new(0.22, 0.42, 0.22), Color3.fromRGB(26, 22, 18), Enum.Material.Slate)
		rightSpike.CFrame = head.CFrame * CFrame.new(hW * 0.34, hH * 0.30, -hD * 0.52) * CFrame.Angles(math.rad(-25), 0, math.rad(15))
		addMesh(rightSpike, Enum.MeshType.Pyramid)
		weldParts(head, rightSpike)

		-- 6. 3-Tiered Jagged Volcanic Mohawk Crest
		local crest1 = makePart(helm, "HelmCrest1", Vector3.new(0.26, 0.58, 0.68), Color3.fromRGB(48, 42, 36), Enum.Material.Cobblestone)
		crest1.CFrame = head.CFrame * CFrame.new(0, hH * 0.72, -0.15) * CFrame.Angles(math.rad(-12), 0, 0)
		addMesh(crest1, Enum.MeshType.Wedge)
		weldParts(head, crest1)

		local crest2 = makePart(helm, "HelmCrest2", Vector3.new(0.24, 0.50, 0.60), Color3.fromRGB(40, 36, 30), Enum.Material.Slate)
		crest2.CFrame = head.CFrame * CFrame.new(0, hH * 0.65, 0.35) * CFrame.Angles(math.rad(15), 0, 0)
		addMesh(crest2, Enum.MeshType.Wedge)
		weldParts(head, crest2)

		-- Volcanic heat vent particle emitter on crest
		local crestEmitter = Instance.new("ParticleEmitter")
		crestEmitter.Name = "VolcanicVents"
		crestEmitter.LightEmission = 1
		crestEmitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 70, 15)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 5)),
		})
		crestEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(1, 0),
		})
		crestEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		crestEmitter.Lifetime = NumberRange.new(0.4, 0.7)
		crestEmitter.Rate = 2.5
		crestEmitter.Speed = NumberRange.new(0.2, 0.6)
		crestEmitter.SpreadAngle = Vector2.new(25, 25)
		crestEmitter.Enabled = true
		crestEmitter.Parent = crest1

		-- 7. Glowing Magma Visor Eye-Slit
		local visor = makePart(helm, "HelmVisor", Vector3.new(hW * 0.78, 0.18, 0.26), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
		visor.CFrame = head.CFrame * CFrame.new(0, 0.05, -hD * 0.50)
		addMesh(visor, Enum.MeshType.Sphere, Vector3.new(1.0, 0.55, 0.8))
		weldParts(head, visor)

		local visorLight = Instance.new("PointLight")
		visorLight.Name = "VisorGlow"
		visorLight.Color = Color3.fromRGB(255, 110, 20)
		visorLight.Range = 6
		visorLight.Brightness = 1.4
		visorLight.Parent = visor

		-- 8. Menacing Jaw Mandible Plates & Beast Fangs
		local leftCheek = makePart(helm, "LeftCheek", Vector3.new(0.20, 0.68, hD * 0.55), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
		leftCheek.CFrame = head.CFrame * CFrame.new(-hW * 0.52, -0.15, -0.05)
		addMesh(leftCheek, Enum.MeshType.Wedge)
		weldParts(head, leftCheek)

		local leftFang = makePart(helm, "LeftFang", Vector3.new(0.16, 0.38, 0.24), Color3.fromRGB(25, 22, 18), Enum.Material.Slate)
		leftFang.CFrame = head.CFrame * CFrame.new(-hW * 0.42, -0.38, -hD * 0.38) * CFrame.Angles(math.rad(25), 0, math.rad(-15))
		addMesh(leftFang, Enum.MeshType.Pyramid)
		weldParts(head, leftFang)

		local rightCheek = makePart(helm, "RightCheek", Vector3.new(0.20, 0.68, hD * 0.55), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
		rightCheek.CFrame = head.CFrame * CFrame.new(hW * 0.52, -0.15, -0.05)
		addMesh(rightCheek, Enum.MeshType.Wedge)
		weldParts(head, rightCheek)

		local rightFang = makePart(helm, "RightFang", Vector3.new(0.16, 0.38, 0.24), Color3.fromRGB(25, 22, 18), Enum.Material.Slate)
		rightFang.CFrame = head.CFrame * CFrame.new(hW * 0.42, -0.38, -hD * 0.38) * CFrame.Angles(math.rad(25), 0, math.rad(15))
		addMesh(rightFang, Enum.MeshType.Pyramid)
		weldParts(head, rightFang)

		-- 9. Tiered Nape Scales (protects back of neck)
		local napeScales = makePart(helm, "NapeScales", Vector3.new(hW * 0.96, 0.38, 0.18), Color3.fromRGB(30, 26, 22), Enum.Material.Slate)
		napeScales.CFrame = head.CFrame * CFrame.new(0, -0.16, hD * 0.50) * CFrame.Angles(math.rad(-20), 0, 0)
		weldParts(head, napeScales)

	elseif helmId == "StandardHelm" then
		-- Standard Adventurer Open-Face Iron Helmet (face & hair fully visible)
		-- 1. Crown Skull Cap (fits top of head snugly)
		local skullCap = makePart(helm, "IronDome", Vector3.new(hW * 0.98, hH * 0.46, hD * 0.98), Color3.fromRGB(110, 115, 125), Enum.Material.Metal)
		skullCap.CFrame = head.CFrame * CFrame.new(0, hH * 0.36, 0)
		addMesh(skullCap, Enum.MeshType.Sphere, Vector3.new(1.0, 0.65, 1.0))
		weldParts(head, skullCap)

		-- 2. Forehead Brow Reinforcing Band (rests above eyebrows, leaving face 100% visible)
		local browBand = makePart(helm, "BrowBand", Vector3.new(hW * 1.02, 0.16, hD * 1.02), Color3.fromRGB(75, 80, 90), Enum.Material.Metal)
		browBand.CFrame = head.CFrame * CFrame.new(0, hH * 0.18, 0)
		weldParts(head, browBand)

		-- 3 Iron Rivets on brow band
		for _, xOff in {-0.35, 0, 0.35} do
			local rivet = makePart(helm, "BrowRivet", Vector3.new(0.08, 0.08, 0.08), Color3.fromRGB(140, 145, 155), Enum.Material.Metal)
			rivet.CFrame = head.CFrame * CFrame.new(xOff, hH * 0.18, -hD * 0.52)
			addMesh(rivet, Enum.MeshType.Sphere)
			weldParts(head, rivet)
		end

		-- 3. Side Ear Guards (flush against side of head, leaves face open)
		local leftEar = makePart(helm, "LeftEarGuard", Vector3.new(0.12, 0.36, hD * 0.35), Color3.fromRGB(105, 110, 120), Enum.Material.Metal)
		leftEar.CFrame = head.CFrame * CFrame.new(-hW * 0.50, -0.04, -0.02)
		weldParts(head, leftEar)

		local rightEar = makePart(helm, "RightEarGuard", Vector3.new(0.12, 0.36, hD * 0.35), Color3.fromRGB(105, 110, 120), Enum.Material.Metal)
		rightEar.CFrame = head.CFrame * CFrame.new(hW * 0.50, -0.04, -0.02)
		weldParts(head, rightEar)

		-- 4. Rear Nape Protector Rim
		local napeRim = makePart(helm, "NapeRim", Vector3.new(hW * 0.94, 0.22, 0.14), Color3.fromRGB(75, 80, 90), Enum.Material.Metal)
		napeRim.CFrame = head.CFrame * CFrame.new(0, hH * 0.08, hD * 0.50) * CFrame.Angles(math.rad(-12), 0, 0)
		weldParts(head, napeRim)

	elseif helmId == "ApprenticeHood" then
		-- ── Apprentice Wizard Hat (Tall pointed indigo cap) ──────────────────
		-- Brim: flat ring around base of head
		local brim = makePart(helm, "HatBrim", Vector3.new(hW * 1.45, 0.10, hD * 1.45), Color3.fromRGB(30, 28, 55), Enum.Material.Fabric)
		brim.CFrame = head.CFrame * CFrame.new(0, hH * 0.18, 0)
		local brimMesh = Instance.new("SpecialMesh")
		brimMesh.MeshType = Enum.MeshType.Cylinder
		brimMesh.Scale = Vector3.new(0.1, 1, 1)
		brimMesh.Parent = brim
		weldParts(head, brim)

		-- Brim gold trim ring
		local brimTrim = makePart(helm, "BrimTrim", Vector3.new(hW * 1.48, 0.07, hD * 1.48), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
		brimTrim.CFrame = head.CFrame * CFrame.new(0, hH * 0.16, 0)
		local brimTrimMesh = Instance.new("SpecialMesh")
		brimTrimMesh.MeshType = Enum.MeshType.Cylinder
		brimTrimMesh.Scale = Vector3.new(0.06, 1, 1)
		brimTrimMesh.Parent = brimTrim
		weldParts(head, brimTrim)

		-- Crown base (joins brim to cone)
		local crownBase = makePart(helm, "CrownBase", Vector3.new(hW * 1.05, 0.32, hD * 1.08), Color3.fromRGB(35, 32, 68), Enum.Material.Fabric)
		crownBase.CFrame = head.CFrame * CFrame.new(0, hH * 0.40, 0)
		addMesh(crownBase, Enum.MeshType.Cylinder, Vector3.new(0.32, 1, 1))
		weldParts(head, crownBase)

		-- Tall cone body (the main wizard hat peak)
		local cone1 = makePart(helm, "HatCone1", Vector3.new(hW * 0.90, 0.60, hD * 0.92), Color3.fromRGB(40, 36, 80), Enum.Material.Fabric)
		cone1.CFrame = head.CFrame * CFrame.new(0, hH * 0.72, 0)
		addMesh(cone1, Enum.MeshType.Cylinder, Vector3.new(0.60, 1, 1))
		weldParts(head, cone1)

		local cone2 = makePart(helm, "HatCone2", Vector3.new(hW * 0.60, 0.55, hD * 0.62), Color3.fromRGB(42, 38, 85), Enum.Material.Fabric)
		cone2.CFrame = head.CFrame * CFrame.new(0, hH * 1.10, 0)
		addMesh(cone2, Enum.MeshType.Cylinder, Vector3.new(0.55, 1, 1))
		weldParts(head, cone2)

		local cone3 = makePart(helm, "HatCone3", Vector3.new(hW * 0.32, 0.48, hD * 0.34), Color3.fromRGB(38, 34, 75), Enum.Material.Fabric)
		cone3.CFrame = head.CFrame * CFrame.new(0, hH * 1.44, 0)
		addMesh(cone3, Enum.MeshType.Cylinder, Vector3.new(0.48, 1, 1))
		weldParts(head, cone3)

		local cone4 = makePart(helm, "HatCone4", Vector3.new(hW * 0.14, 0.36, hD * 0.15), Color3.fromRGB(35, 30, 68), Enum.Material.Fabric)
		cone4.CFrame = head.CFrame * CFrame.new(0, hH * 1.74, 0)
		addMesh(cone4, Enum.MeshType.Cylinder, Vector3.new(0.36, 1, 1))
		weldParts(head, cone4)

		-- Tip
		local tip = makePart(helm, "HatTip", Vector3.new(0.08, 0.14, 0.08), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
		tip.CFrame = head.CFrame * CFrame.new(0, hH * 2.0, 0)
		addMesh(tip, Enum.MeshType.Sphere)
		weldParts(head, tip)

		-- Cloth drape at back (flowing behind)
		local drape = makePart(helm, "HoodDrape", Vector3.new(hW * 0.95, 0.80, 0.28), Color3.fromRGB(28, 26, 52), Enum.Material.Fabric)
		drape.CFrame = head.CFrame * CFrame.new(0, hH * 0.05, hD * 0.42) * CFrame.Angles(math.rad(-20), 0, 0)
		weldParts(head, drape)

		local drape2 = makePart(helm, "HoodDrape2", Vector3.new(hW * 0.82, 0.60, 0.22), Color3.fromRGB(24, 22, 46), Enum.Material.Fabric)
		drape2.CFrame = head.CFrame * CFrame.new(0, -hH * 0.28, hD * 0.52) * CFrame.Angles(math.rad(-28), 0, 0)
		weldParts(head, drape2)

		-- Small star gem on brim front
		local starGem = makePart(helm, "StarGem", Vector3.new(0.10, 0.10, 0.06), Color3.fromRGB(120, 160, 255), Enum.Material.Neon)
		starGem.CFrame = head.CFrame * CFrame.new(0, hH * 0.20, -hD * 0.72)
		addMesh(starGem, Enum.MeshType.Sphere)
		weldParts(head, starGem)

	elseif helmId == "RockhideCowl" then
		-- ── Rockhide Wizard Hat (Tall basalt stone cap — clearly superior) ────
		-- Brim: wide flat basalt stone brim
		local brim = makePart(helm, "HatBrim", Vector3.new(hW * 1.60, 0.12, hD * 1.60), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
		brim.CFrame = head.CFrame * CFrame.new(0, hH * 0.18, 0)
		local brimMesh = Instance.new("SpecialMesh")
		brimMesh.MeshType = Enum.MeshType.Cylinder
		brimMesh.Scale = Vector3.new(0.1, 1, 1)
		brimMesh.Parent = brim
		weldParts(head, brim)

		-- Brim outer lava crack ring
		local brimLava = makePart(helm, "BrimLavaCrack", Vector3.new(hW * 1.62, 0.05, hD * 1.62), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
		brimLava.CFrame = head.CFrame * CFrame.new(0, hH * 0.14, 0)
		local brimLavaMesh = Instance.new("SpecialMesh")
		brimLavaMesh.MeshType = Enum.MeshType.Cylinder
		brimLavaMesh.Scale = Vector3.new(0.04, 1, 1)
		brimLavaMesh.Parent = brimLava
		weldParts(head, brimLava)

		-- Stone brim edge trim (dark obsidian)
		local brimEdge = makePart(helm, "BrimEdge", Vector3.new(hW * 1.58, 0.08, hD * 1.58), Color3.fromRGB(22, 20, 18), Enum.Material.Cobblestone)
		brimEdge.CFrame = head.CFrame * CFrame.new(0, hH * 0.22, 0)
		local brimEdgeMesh = Instance.new("SpecialMesh")
		brimEdgeMesh.MeshType = Enum.MeshType.Cylinder
		brimEdgeMesh.Scale = Vector3.new(0.06, 1, 1)
		brimEdgeMesh.Parent = brimEdge
		weldParts(head, brimEdge)

		-- Crown base (chunky stone base)
		local crownBase = makePart(helm, "CrownBase", Vector3.new(hW * 1.06, 0.35, hD * 1.10), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
		crownBase.CFrame = head.CFrame * CFrame.new(0, hH * 0.42, 0)
		addMesh(crownBase, Enum.MeshType.Cylinder, Vector3.new(0.35, 1, 1))
		weldParts(head, crownBase)

		-- Rune band on crown base (glowing orange)
		local runeBand = makePart(helm, "RuneBand", Vector3.new(hW * 1.08, 0.08, hD * 1.12), Color3.fromRGB(255, 115, 25), Enum.Material.Neon)
		runeBand.CFrame = head.CFrame * CFrame.new(0, hH * 0.55, 0)
		addMesh(runeBand, Enum.MeshType.Cylinder, Vector3.new(0.08, 1, 1))
		weldParts(head, runeBand)

		-- Tall stone cone body
		local cone1 = makePart(helm, "HatCone1", Vector3.new(hW * 0.94, 0.65, hD * 0.96), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		cone1.CFrame = head.CFrame * CFrame.new(0, hH * 0.80, 0)
		addMesh(cone1, Enum.MeshType.Cylinder, Vector3.new(0.65, 1, 1))
		weldParts(head, cone1)

		local cone2 = makePart(helm, "HatCone2", Vector3.new(hW * 0.65, 0.60, hD * 0.67), Color3.fromRGB(30, 26, 22), Enum.Material.Cobblestone)
		cone2.CFrame = head.CFrame * CFrame.new(0, hH * 1.22, 0)
		addMesh(cone2, Enum.MeshType.Cylinder, Vector3.new(0.60, 1, 1))
		weldParts(head, cone2)

		-- Mid lava crack ring on cone
		local midCrack = makePart(helm, "MidLavaCrack", Vector3.new(hW * 0.68, 0.06, hD * 0.70), Color3.fromRGB(255, 100, 15), Enum.Material.Neon)
		midCrack.CFrame = head.CFrame * CFrame.new(0, hH * 1.20, 0)
		addMesh(midCrack, Enum.MeshType.Cylinder, Vector3.new(0.06, 1, 1))
		weldParts(head, midCrack)

		local cone3 = makePart(helm, "HatCone3", Vector3.new(hW * 0.38, 0.52, hD * 0.40), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
		cone3.CFrame = head.CFrame * CFrame.new(0, hH * 1.60, 0)
		addMesh(cone3, Enum.MeshType.Cylinder, Vector3.new(0.52, 1, 1))
		weldParts(head, cone3)

		local cone4 = makePart(helm, "HatCone4", Vector3.new(hW * 0.18, 0.42, hD * 0.19), Color3.fromRGB(24, 20, 16), Enum.Material.Slate)
		cone4.CFrame = head.CFrame * CFrame.new(0, hH * 1.96, 0)
		addMesh(cone4, Enum.MeshType.Cylinder, Vector3.new(0.42, 1, 1))
		weldParts(head, cone4)

		-- Upper lava crack ring
		local upperCrack = makePart(helm, "UpperLavaCrack", Vector3.new(hW * 0.40, 0.05, hD * 0.42), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
		upperCrack.CFrame = head.CFrame * CFrame.new(0, hH * 1.58, 0)
		addMesh(upperCrack, Enum.MeshType.Cylinder, Vector3.new(0.05, 1, 1))
		weldParts(head, upperCrack)

		-- Gemstone cap at peak (pulsing amethyst orb)
		local gemBase = makePart(helm, "GemBase", Vector3.new(0.26, 0.26, 0.26), Color3.fromRGB(22, 18, 14), Enum.Material.Slate)
		gemBase.CFrame = head.CFrame * CFrame.new(0, hH * 2.22, 0)
		addMesh(gemBase, Enum.MeshType.Sphere)
		weldParts(head, gemBase)

		local gem = makePart(helm, "PeakGem", Vector3.new(0.20, 0.20, 0.20), Color3.fromRGB(200, 100, 255), Enum.Material.Neon)
		gem.CFrame = head.CFrame * CFrame.new(0, hH * 2.24, 0)
		addMesh(gem, Enum.MeshType.Sphere)
		weldParts(head, gem)

		-- Gem glow light
		local gemLight = Instance.new("PointLight")
		gemLight.Name = "GemGlow"
		gemLight.Color = Color3.fromRGB(180, 80, 255)
		gemLight.Range = 8
		gemLight.Brightness = 2.0
		gemLight.Parent = gem

		-- Brim lava glow light
		local brimLight = Instance.new("PointLight")
		brimLight.Name = "BrimLavaGlow"
		brimLight.Color = Color3.fromRGB(255, 105, 20)
		brimLight.Range = 5
		brimLight.Brightness = 1.2
		brimLight.Parent = brimLava

		-- Orbiting ember particles from peak gem
		local emberEmitter = Instance.new("ParticleEmitter")
		emberEmitter.Name = "HatEmbers"
		emberEmitter.LightEmission = 1
		emberEmitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 5)),
		})
		emberEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.6, 0.05),
			NumberSequenceKeypoint.new(1, 0),
		})
		emberEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.0),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		emberEmitter.SpreadAngle = Vector2.new(60, 60)
		emberEmitter.Speed = NumberRange.new(0.8, 2.0)
		emberEmitter.Rate = 8
		emberEmitter.Lifetime = NumberRange.new(0.8, 1.4)
		emberEmitter.RotSpeed = NumberRange.new(-45, 45)
		emberEmitter.Parent = gem

		-- Obsidian front ridge (decorative stone fin on front face)
		local ridge = makePart(helm, "ObsidianRidge", Vector3.new(0.10, hH * 0.80, 0.12), Color3.fromRGB(18, 14, 12), Enum.Material.Slate)
		ridge.CFrame = head.CFrame * CFrame.new(0, hH * 0.90, -hD * 0.52)
		weldParts(head, ridge)

		local ridgeGlow = makePart(helm, "RidgeGlow", Vector3.new(0.06, hH * 0.75, 0.06), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
		ridgeGlow.CFrame = head.CFrame * CFrame.new(0, hH * 0.90, -hD * 0.55)
		weldParts(head, ridgeGlow)

		-- Glowing Magma Eye Facets on brow area
		for _, xOff in {-0.26, 0.26} do
			local eyeFacet = makePart(helm, "EyeFacet", Vector3.new(0.20, 0.11, 0.13), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
			eyeFacet.CFrame = head.CFrame * CFrame.new(xOff, hH * 0.22, -hD * 0.58)
			addMesh(eyeFacet, Enum.MeshType.Sphere)
			weldParts(head, eyeFacet)
		end
	end

	helm.Parent = character
end

local function attachChest(character: Model, chestId: string?)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return end
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local existing = character:FindFirstChild("EquippedChest")
	if existing then existing:Destroy() end
	if not chestId then return end

	local chest = Instance.new("Model")
	chest.Name = "EquippedChest"

	local isR15 = lowerTorso ~= nil
	local tW = isR15 and 1.68 or 2.05
	local tH = isR15 and 1.15 or 1.95

	if chestId == "RockhideChest" then
		-- Monster Hunter Behemoth Wyvern Carapace Cuirass
		local targetWaist = lowerTorso or torso

		-- 1. 3 Overlapping Scalloped Carapace Scutes on Front
		local scute1 = makePart(chest, "CarapaceScute1", Vector3.new(tW * 0.96, 0.46, 0.24), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		scute1.CFrame = torso.CFrame * CFrame.new(0, tH * 0.25, -0.54)
		weldParts(torso, scute1)

		local scute2 = makePart(chest, "CarapaceScute2", Vector3.new(tW * 0.88, 0.42, 0.26), Color3.fromRGB(42, 38, 34), Enum.Material.Slate)
		scute2.CFrame = torso.CFrame * CFrame.new(0, -tH * 0.08, -0.56)
		weldParts(torso, scute2)

		local scute3 = makePart(chest, "CarapaceScute3", Vector3.new(tW * 0.80, 0.36, 0.22), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		scute3.CFrame = targetWaist.CFrame * CFrame.new(0, isR15 and 0.18 or -tH * 0.30, -0.54)
		addMesh(scute3, Enum.MeshType.Wedge)
		weldParts(targetWaist, scute3)

		-- 2. Central Volcanic Core Hearth (Diamond socket with molten stone)
		local coreMount = makePart(chest, "MagmaCoreMount", Vector3.new(0.68, 0.68, 0.24), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
		coreMount.CFrame = torso.CFrame * CFrame.new(0, 0.06, -0.60) * CFrame.Angles(0, 0, math.rad(45))
		addMesh(coreMount, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.8))
		weldParts(torso, coreMount)

		local core = makePart(chest, "MagmaCore", Vector3.new(0.52, 0.52, 0.28), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
		core.CFrame = torso.CFrame * CFrame.new(0, 0.06, -0.63) * CFrame.Angles(0, 0, math.rad(45))
		addMesh(core, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.85))
		weldParts(torso, core)

		local coreLight = Instance.new("PointLight")
		coreLight.Name = "CoreGlow"
		coreLight.Color = Color3.fromRGB(255, 110, 20)
		coreLight.Range = 7
		coreLight.Brightness = 1.6
		coreLight.Parent = core

		-- Ambient chest magma embers
		local coreEmitter = Instance.new("ParticleEmitter")
		coreEmitter.Name = "ChestMagmaEmbers"
		coreEmitter.LightEmission = 1
		coreEmitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 5)),
		})
		coreEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(1, 0),
		})
		coreEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.20),
			NumberSequenceKeypoint.new(1, 1),
		})
		coreEmitter.Lifetime = NumberRange.new(0.3, 0.6)
		coreEmitter.Rate = 2.5
		coreEmitter.Speed = NumberRange.new(0.2, 0.5)
		coreEmitter.SpreadAngle = Vector2.new(30, 30)
		coreEmitter.Enabled = true
		coreEmitter.Parent = core

		-- 3. 4 Branching Magma Fissure Veins Across Pectorals and Flanks
		local veinConfigs = {
			{x = -0.38, y = 0.28, rot = 28},
			{x = 0.38, y = 0.28, rot = -28},
			{x = -0.32, y = -0.15, rot = -22},
			{x = 0.32, y = -0.15, rot = 22},
		}
		for i, vc in ipairs(veinConfigs) do
			local vein = makePart(chest, "MagmaVein_" .. i, Vector3.new(0.78, 0.12, 0.16), Color3.fromRGB(255, 95, 18), Enum.Material.Neon)
			vein.CFrame = torso.CFrame * CFrame.new(vc.x, vc.y, -0.60) * CFrame.Angles(0, 0, math.rad(vc.rot))
			addMesh(vein, Enum.MeshType.Sphere, Vector3.new(1.0, 0.45, 0.45))
			weldParts(torso, vein)
		end

		-- 4. Heavy Spiked Throat Gorget with 2 Forward Rock Barbs
		local gorget = makePart(chest, "Gorget", Vector3.new(tW * 0.78, 0.30, 0.96), Color3.fromRGB(32, 28, 24), Enum.Material.Cobblestone)
		gorget.CFrame = torso.CFrame * CFrame.new(0, tH * 0.52, 0)
		addMesh(gorget, Enum.MeshType.Sphere, Vector3.new(1.15, 0.5, 1.15))
		weldParts(torso, gorget)

		for _, sDir in {-1, 1} do
			local gBarb = makePart(chest, "GorgetBarb_" .. sDir, Vector3.new(0.20, 0.35, 0.20), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
			gBarb.CFrame = torso.CFrame * CFrame.new(sDir * 0.32, tH * 0.55, -0.48) * CFrame.Angles(math.rad(28), 0, sDir * math.rad(-15))
			addMesh(gBarb, Enum.MeshType.Pyramid)
			weldParts(torso, gBarb)
		end

		-- 5. Sturdy Weathered Leather Shoulder Harness Straps
		local strapL = makePart(chest, "LeatherStrapL", Vector3.new(0.24, 0.12, 1.10), Color3.fromRGB(52, 38, 26), Enum.Material.Fabric)
		strapL.CFrame = torso.CFrame * CFrame.new(-tW * 0.34, tH * 0.48, 0)
		weldParts(torso, strapL)

		local strapR = makePart(chest, "LeatherStrapR", Vector3.new(0.24, 0.12, 1.10), Color3.fromRGB(52, 38, 26), Enum.Material.Fabric)
		strapR.CFrame = torso.CFrame * CFrame.new(tW * 0.34, tH * 0.48, 0)
		weldParts(torso, strapR)

		-- 6. Carapace Backplate with 3 Menacing Wyvern Dorsal Spines
		local backPlate = makePart(chest, "CarapaceBack", Vector3.new(tW * 0.94, tH * 0.88, 0.22), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
		backPlate.CFrame = torso.CFrame * CFrame.new(0, 0.02, 0.54)
		weldParts(torso, backPlate)

		local dorsalSpines = {
			{y = 0.32, sz = Vector3.new(0.28, 0.55, 0.46)},
			{y = 0.02, sz = Vector3.new(0.25, 0.48, 0.40)},
			{y = -0.28, sz = Vector3.new(0.22, 0.40, 0.34)},
		}
		for idx, sp in ipairs(dorsalSpines) do
			local spine = makePart(chest, "DorsalSpine_" .. idx, sp.sz, Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
			spine.CFrame = torso.CFrame * CFrame.new(0, sp.y, 0.68) * CFrame.Angles(math.rad(-25), 0, 0)
			addMesh(spine, Enum.MeshType.Pyramid)
			weldParts(torso, spine)
		end

		-- 7. Reinforced Leather Warbelt & Flared Spiked Hip Tassets
		local beltY = isR15 and -0.10 or -tH * 0.35
		local warBelt = makePart(chest, "WarBelt", Vector3.new(tW * 0.94, 0.20, 1.06), Color3.fromRGB(44, 32, 22), Enum.Material.Fabric)
		warBelt.CFrame = targetWaist.CFrame * CFrame.new(0, beltY, 0)
		weldParts(targetWaist, warBelt)

		local leftTasset = makePart(chest, "LeftTasset", Vector3.new(0.70, 0.88, 0.24), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		leftTasset.CFrame = targetWaist.CFrame * CFrame.new(-tW * 0.50, -0.35, 0) * CFrame.Angles(0, 0, math.rad(14))
		addMesh(leftTasset, Enum.MeshType.Wedge)
		weldParts(targetWaist, leftTasset)

		local leftTassetSpike = makePart(chest, "LeftTassetSpike", Vector3.new(0.20, 0.38, 0.22), Color3.fromRGB(26, 22, 18), Enum.Material.Slate)
		leftTassetSpike.CFrame = targetWaist.CFrame * CFrame.new(-tW * 0.62, -0.52, 0) * CFrame.Angles(0, 0, math.rad(35))
		addMesh(leftTassetSpike, Enum.MeshType.Pyramid)
		weldParts(targetWaist, leftTassetSpike)

		local rightTasset = makePart(chest, "RightTasset", Vector3.new(0.70, 0.88, 0.24), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		rightTasset.CFrame = targetWaist.CFrame * CFrame.new(tW * 0.50, -0.35, 0) * CFrame.Angles(0, 0, math.rad(-14))
		addMesh(rightTasset, Enum.MeshType.Wedge)
		weldParts(targetWaist, rightTasset)

		local rightTassetSpike = makePart(chest, "RightTassetSpike", Vector3.new(0.20, 0.38, 0.22), Color3.fromRGB(26, 22, 18), Enum.Material.Slate)
		rightTassetSpike.CFrame = targetWaist.CFrame * CFrame.new(tW * 0.62, -0.52, 0) * CFrame.Angles(0, 0, math.rad(-35))
		addMesh(rightTassetSpike, Enum.MeshType.Pyramid)
		weldParts(targetWaist, rightTassetSpike)

	elseif chestId == "StandardChest" then
		-- Standard Adventurer Iron Breastplate & Leather Harness
		-- 1. Front Form-Fitting Iron Breastplate
		local breastplate = makePart(chest, "IronBreastplate", Vector3.new(tW * 0.88, tH * 0.78, 0.14), Color3.fromRGB(115, 120, 130), Enum.Material.Metal)
		breastplate.CFrame = torso.CFrame * CFrame.new(0, 0.02, -0.52)
		weldParts(torso, breastplate)

		-- 2. Subtle Iron Center Seam Ridge
		local centerRidge = makePart(chest, "CenterRidge", Vector3.new(0.10, tH * 0.74, 0.16), Color3.fromRGB(85, 90, 100), Enum.Material.Metal)
		centerRidge.CFrame = torso.CFrame * CFrame.new(0, 0.02, -0.54)
		weldParts(torso, centerRidge)

		-- 3. 4 Corner Rivets on Breastplate
		for _, xDir in {-1, 1} do
			for _, yDir in {-1, 1} do
				local rivet = makePart(chest, "PlateRivet", Vector3.new(0.10, 0.10, 0.10), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
				rivet.CFrame = torso.CFrame * CFrame.new(xDir * tW * 0.34, yDir * tH * 0.28, -0.56)
				addMesh(rivet, Enum.MeshType.Sphere)
				weldParts(torso, rivet)
			end
		end

		-- 4. Sturdy Leather Shoulder Harness Straps
		local leftStrap = makePart(chest, "ShoulderStrapL", Vector3.new(0.22, 0.10, 1.08), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
		leftStrap.CFrame = torso.CFrame * CFrame.new(-tW * 0.32, tH * 0.48, 0)
		weldParts(torso, leftStrap)

		local rightStrap = makePart(chest, "ShoulderStrapR", Vector3.new(0.22, 0.10, 1.08), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
		rightStrap.CFrame = torso.CFrame * CFrame.new(tW * 0.32, tH * 0.48, 0)
		weldParts(torso, rightStrap)

		-- 5. Iron Back Protector Plate
		local backplate = makePart(chest, "IronBackplate", Vector3.new(tW * 0.82, tH * 0.70, 0.12), Color3.fromRGB(105, 110, 120), Enum.Material.Metal)
		backplate.CFrame = torso.CFrame * CFrame.new(0, 0.02, 0.52)
		weldParts(torso, backplate)

		-- 6. Side Leather Buckle Straps
		local sideStrapL = makePart(chest, "SideStrapL", Vector3.new(0.12, 0.14, 1.04), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
		sideStrapL.CFrame = torso.CFrame * CFrame.new(-tW * 0.46, 0, 0)
		weldParts(torso, sideStrapL)

		local sideStrapR = makePart(chest, "SideStrapR", Vector3.new(0.12, 0.14, 1.04), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
		sideStrapR.CFrame = torso.CFrame * CFrame.new(tW * 0.46, 0, 0)
		weldParts(torso, sideStrapR)

		-- 7. Waist Leather Belt with Iron Buckle
		local targetWaist = lowerTorso or torso
		local beltY = isR15 and -0.15 or -tH * 0.35
		local belt = makePart(chest, "WaistBelt", Vector3.new(tW * 0.94, 0.18, 1.06), Color3.fromRGB(48, 34, 24), Enum.Material.Fabric)
		belt.CFrame = targetWaist.CFrame * CFrame.new(0, beltY, 0)
		weldParts(targetWaist, belt)

		local buckle = makePart(chest, "BeltBuckle", Vector3.new(0.28, 0.22, 0.14), Color3.fromRGB(145, 150, 160), Enum.Material.Metal)
		buckle.CFrame = targetWaist.CFrame * CFrame.new(0, beltY, -0.54)
		weldParts(targetWaist, buckle)

	elseif chestId == "ApprenticeRobe" then
		-- Mage Starter Robe (Indigo Scholar Vestments)
		local robeTorso = makePart(chest, "RobeTorso", Vector3.new(tW * 0.96, tH * 0.90, 1.08), Color3.fromRGB(35, 38, 70), Enum.Material.Fabric)
		robeTorso.CFrame = torso.CFrame * CFrame.new(0, 0, 0)
		weldParts(torso, robeTorso)

		local goldSash = makePart(chest, "GoldSash", Vector3.new(0.24, tH * 0.88, 0.16), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
		goldSash.CFrame = torso.CFrame * CFrame.new(0, 0, -0.55)
		weldParts(torso, goldSash)

		local targetWaist = lowerTorso or torso
		local robeSkirt = makePart(chest, "RobeSkirt", Vector3.new(tW * 0.98, 0.45, 1.10), Color3.fromRGB(28, 30, 58), Enum.Material.Fabric)
		robeSkirt.CFrame = targetWaist.CFrame * CFrame.new(0, isR15 and -0.15 or -tH * 0.38, 0)
		weldParts(targetWaist, robeSkirt)

	elseif chestId == "RockhideRobes" then
		-- ── Rockhide Geomancer Robes (Earthcaller's Volcanic Vestments) ──────
		-- Main robe body (dark basalt-tinted robes)
		local robeTorso = makePart(chest, "RobeTorso", Vector3.new(tW * 0.98, tH * 0.92, 1.12), Color3.fromRGB(28, 24, 20), Enum.Material.Fabric)
		robeTorso.CFrame = torso.CFrame * CFrame.new(0, 0, 0)
		weldParts(torso, robeTorso)

		-- Front stone overlay panels (layered basalt scutes)
		local scuteTop = makePart(chest, "ScuteTop", Vector3.new(tW * 0.92, 0.44, 0.22), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		scuteTop.CFrame = torso.CFrame * CFrame.new(0, tH * 0.28, -0.57)
		weldParts(torso, scuteTop)

		local scuteMid = makePart(chest, "ScuteMid", Vector3.new(tW * 0.84, 0.40, 0.24), Color3.fromRGB(42, 38, 34), Enum.Material.Cobblestone)
		scuteMid.CFrame = torso.CFrame * CFrame.new(0, -tH * 0.05, -0.58)
		weldParts(torso, scuteMid)

		-- Left & Right stone shoulder guards
		local shoulderL = makePart(chest, "ShoulderGuardL", Vector3.new(tW * 0.28, 0.30, 0.26), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		shoulderL.CFrame = torso.CFrame * CFrame.new(-tW * 0.36, tH * 0.38, -0.52)
		addMesh(shoulderL, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1))
		weldParts(torso, shoulderL)

		local shoulderR = makePart(chest, "ShoulderGuardR", Vector3.new(tW * 0.28, 0.30, 0.26), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
		shoulderR.CFrame = torso.CFrame * CFrame.new(tW * 0.36, tH * 0.38, -0.52)
		addMesh(shoulderR, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1))
		weldParts(torso, shoulderR)

		-- Glowing Central Magma Hearth Core
		local coreMount = makePart(chest, "MagmaMount", Vector3.new(0.52, 0.52, 0.22), Color3.fromRGB(22, 18, 14), Enum.Material.Slate)
		coreMount.CFrame = torso.CFrame * CFrame.new(0, 0.06, -0.60) * CFrame.Angles(0, 0, math.rad(45))
		addMesh(coreMount, Enum.MeshType.Sphere, Vector3.new(1.0, 1.0, 0.7))
		weldParts(torso, coreMount)

		local magmaCore = makePart(chest, "MagmaHearth", Vector3.new(0.38, 0.38, 0.24), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
		magmaCore.CFrame = torso.CFrame * CFrame.new(0, 0.06, -0.63) * CFrame.Angles(0, 0, math.rad(45))
		addMesh(magmaCore, Enum.MeshType.Sphere)
		weldParts(torso, magmaCore)

		local coreLight = Instance.new("PointLight")
		coreLight.Name = "CoreGlow"
		coreLight.Color = Color3.fromRGB(255, 110, 20)
		coreLight.Range = 8
		coreLight.Brightness = 1.8
		coreLight.Parent = magmaCore

		-- Magma ember particles from core
		local robeEmitter = Instance.new("ParticleEmitter")
		robeEmitter.Name = "RobeEmbers"
		robeEmitter.LightEmission = 1
		robeEmitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 5)),
		})
		robeEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.09),
			NumberSequenceKeypoint.new(0.6, 0.06),
			NumberSequenceKeypoint.new(1, 0),
		})
		robeEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		robeEmitter.SpreadAngle = Vector2.new(80, 80)
		robeEmitter.Speed = NumberRange.new(0.5, 1.5)
		robeEmitter.Rate = 6
		robeEmitter.Lifetime = NumberRange.new(0.8, 1.2)
		robeEmitter.Parent = magmaCore

		-- Glowing rune waist band
		local targetWaist = lowerTorso or torso
		local runeWaist = makePart(chest, "RuneWaistBand", Vector3.new(tW * 1.0, 0.10, 1.14), Color3.fromRGB(255, 115, 25), Enum.Material.Neon)
		runeWaist.CFrame = targetWaist.CFrame * CFrame.new(0, isR15 and 0.12 or -tH * 0.12, 0)
		weldParts(targetWaist, runeWaist)

		-- Skirt (wide layered basalt-edged robe)
		local robeSkirt = makePart(chest, "RobeSkirt", Vector3.new(tW * 1.06, 0.55, 1.16), Color3.fromRGB(24, 20, 16), Enum.Material.Fabric)
		robeSkirt.CFrame = targetWaist.CFrame * CFrame.new(0, isR15 and -0.18 or -tH * 0.40, 0)
		weldParts(targetWaist, robeSkirt)

		-- Stone skirt front panel
		local skirtPanel = makePart(chest, "SkirtPanel", Vector3.new(tW * 0.68, 0.50, 0.22), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
		skirtPanel.CFrame = targetWaist.CFrame * CFrame.new(0, isR15 and -0.22 or -tH * 0.45, -0.50)
		addMesh(skirtPanel, Enum.MeshType.Wedge)
		weldParts(targetWaist, skirtPanel)
	end

	chest.Parent = character
end

local function attachPauldrons(character: Model, armsId: string?)
	local existing = character:FindFirstChild("EquippedPauldrons")
	if existing then existing:Destroy() end
	if not armsId then return end

	local leftArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
	local rightArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if not leftArm and not rightArm then return end

	local pauldrons = Instance.new("Model")
	pauldrons.Name = "EquippedPauldrons"

	if armsId == "RockhideArms" then
		-- Monster Hunter Spiked Behemoth Pauldrons & Forearm Wyvern Vambraces
		local armList = {
			{
				arm = leftArm,
				lowerArm = character:FindFirstChild("LeftLowerArm"),
				sign = -1,
				name = "Left",
			},
			{
				arm = rightArm,
				lowerArm = character:FindFirstChild("RightLowerArm"),
				sign = 1,
				name = "Right",
			},
		}
		for _, data in ipairs(armList) do
			if data.arm then
				local s = data.sign

				-- 1. Heavy Rock Carapace Shoulder Cup
				local cup = makePart(pauldrons, data.name .. "CarapaceCup", Vector3.new(1.18, 0.58, 1.18), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
				cup.CFrame = data.arm.CFrame * CFrame.new(s * 0.16, 0.48, 0) * CFrame.Angles(0, 0, s * math.rad(18))
				addMesh(cup, Enum.MeshType.Sphere, Vector3.new(1.15, 0.72, 1.15))
				weldParts(data.arm, cup)

				-- 2. Massive Sweeping Wyvern Horn with Molten Tip
				local horn = makePart(pauldrons, data.name .. "WyvernHorn", Vector3.new(0.38, 1.15, 0.38), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
				horn.CFrame = data.arm.CFrame * CFrame.new(s * 0.45, 1.02, 0) * CFrame.Angles(0, 0, s * math.rad(-38))
				addMesh(horn, Enum.MeshType.Pyramid, Vector3.new(0.9, 1.3, 0.9))
				weldParts(data.arm, horn)

				local hornTip = makePart(pauldrons, data.name .. "HornTip", Vector3.new(0.24, 0.55, 0.24), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
				hornTip.CFrame = data.arm.CFrame * CFrame.new(s * 0.72, 1.48, 0) * CFrame.Angles(0, 0, s * math.rad(-42))
				addMesh(hornTip, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.3, 0.8))
				weldParts(data.arm, hornTip)

				-- 3. Secondary Forward Defensive Rock Horn
				local fSpike = makePart(pauldrons, data.name .. "ForwardSpike", Vector3.new(0.26, 0.58, 0.26), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
				fSpike.CFrame = data.arm.CFrame * CFrame.new(s * 0.26, 0.68, -0.48) * CFrame.Angles(math.rad(32), 0, s * math.rad(-15))
				addMesh(fSpike, Enum.MeshType.Pyramid)
				weldParts(data.arm, fSpike)

				-- 4. Glowing Magma Vein along shoulder
				local vein = makePart(pauldrons, data.name .. "MagmaVein", Vector3.new(0.20, 0.68, 0.20), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
				vein.CFrame = data.arm.CFrame * CFrame.new(s * 0.30, 0.52, -0.42) * CFrame.Angles(0, 0, s * math.rad(12))
				addMesh(vein, Enum.MeshType.Sphere)
				weldParts(data.arm, vein)

				-- 5. Heavy Leather Bicep Fastening Strap
				local bicepStrap = makePart(pauldrons, data.name .. "BicepStrap", Vector3.new(1.08, 0.14, 1.08), Color3.fromRGB(52, 38, 26), Enum.Material.Fabric)
				bicepStrap.CFrame = data.arm.CFrame * CFrame.new(s * 0.08, 0.18, 0)
				weldParts(data.arm, bicepStrap)

				-- 6. FOREARM WYVERN VAMBRACES & PARRYING TALONS
				local targetForearm = data.lowerArm or data.arm
				local isLower = data.lowerArm ~= nil
				local vambraceY = isLower and 0 or -0.45
				local wristY = isLower and -0.22 or -0.65
				local elbowY = isLower and 0.28 or -0.20

				-- Basalt forearm guard plate
				local vambracePlate = makePart(pauldrons, data.name .. "VambracePlate", Vector3.new(0.74, 0.68, 0.22), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
				vambracePlate.CFrame = targetForearm.CFrame * CFrame.new(s * 0.14, vambraceY, -0.24)
				weldParts(targetForearm, vambracePlate)

				-- Forward-swept rock parrying talon / deflector blade
				local parryTalon = makePart(pauldrons, data.name .. "ParryTalon", Vector3.new(0.24, 0.52, 0.28), Color3.fromRGB(26, 22, 18), Enum.Material.Slate)
				parryTalon.CFrame = targetForearm.CFrame * CFrame.new(s * 0.26, vambraceY - 0.05, -0.36) * CFrame.Angles(math.rad(28), 0, s * math.rad(12))
				addMesh(parryTalon, Enum.MeshType.Pyramid, Vector3.new(0.85, 1.3, 0.85))
				weldParts(targetForearm, parryTalon)

				-- Backward defensive elbow rock cop
				local elbowCop = makePart(pauldrons, data.name .. "ElbowCop", Vector3.new(0.24, 0.38, 0.32), Color3.fromRGB(30, 26, 22), Enum.Material.Slate)
				elbowCop.CFrame = targetForearm.CFrame * CFrame.new(0, elbowY, 0.32) * CFrame.Angles(math.rad(-30), 0, 0)
				addMesh(elbowCop, Enum.MeshType.Pyramid)
				weldParts(targetForearm, elbowCop)

				-- Glowing forearm magma vein
				local armVein = makePart(pauldrons, data.name .. "ArmVein", Vector3.new(0.12, 0.58, 0.16), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
				armVein.CFrame = targetForearm.CFrame * CFrame.new(s * 0.16, vambraceY, -0.32)
				addMesh(armVein, Enum.MeshType.Sphere, Vector3.new(0.7, 1.0, 0.7))
				weldParts(targetForearm, armVein)

				-- Tough leather wrist wrap
				local wristWrap = makePart(pauldrons, data.name .. "WristWrap", Vector3.new(0.76, 0.14, 0.76), Color3.fromRGB(48, 34, 24), Enum.Material.Fabric)
				wristWrap.CFrame = targetForearm.CFrame * CFrame.new(0, wristY, 0)
				weldParts(targetForearm, wristWrap)
			end
		end

	elseif armsId == "StandardArms" then
		-- Standard Iron Vambraces & Adventurer Shoulder Cops
		local armList = {
			{
				arm = leftArm,
				lowerArm = character:FindFirstChild("LeftLowerArm"),
				sign = -1,
				name = "Left",
			},
			{
				arm = rightArm,
				lowerArm = character:FindFirstChild("RightLowerArm"),
				sign = 1,
				name = "Right",
			},
		}
		for _, data in ipairs(armList) do
			if data.arm then
				local s = data.sign

				-- 1. Sleek, low-profile iron shoulder cop (flush with shoulder)
				local shoulderCop = makePart(pauldrons, data.name .. "ShoulderCop", Vector3.new(1.02, 0.28, 1.02), Color3.fromRGB(115, 120, 130), Enum.Material.Metal)
				shoulderCop.CFrame = data.arm.CFrame * CFrame.new(s * 0.08, 0.40, 0) * CFrame.Angles(0, 0, s * math.rad(10))
				addMesh(shoulderCop, Enum.MeshType.Sphere, Vector3.new(1.02, 0.48, 1.02))
				weldParts(data.arm, shoulderCop)

				-- Shoulder leather strap
				local shoulderStrap = makePart(pauldrons, data.name .. "ShoulderStrap", Vector3.new(1.04, 0.12, 1.04), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
				shoulderStrap.CFrame = data.arm.CFrame * CFrame.new(s * 0.08, 0.24, 0)
				weldParts(data.arm, shoulderStrap)

				-- 2. Forearm Iron Vambrace (protects outer forearm)
				local targetForearm = data.lowerArm or data.arm
				local isLower = data.lowerArm ~= nil
				local vambraceY = isLower and 0 or -0.45
				local strapY = isLower and -0.22 or -0.65

				local vambrace = makePart(pauldrons, data.name .. "Vambrace", Vector3.new(0.70, 0.60, 0.14), Color3.fromRGB(115, 120, 130), Enum.Material.Metal)
				vambrace.CFrame = targetForearm.CFrame * CFrame.new(s * 0.08, vambraceY, -0.22)
				weldParts(targetForearm, vambrace)

				-- Wrist leather strap
				local wristStrap = makePart(pauldrons, data.name .. "WristStrap", Vector3.new(0.74, 0.10, 0.74), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
				wristStrap.CFrame = targetForearm.CFrame * CFrame.new(0, strapY, 0)
				weldParts(targetForearm, wristStrap)
			end
		end

	elseif armsId == "ApprenticeBracers" then
		-- Mage Starter Bracers (Soft leather wristbands with runic gold trim)
		local armList = {
			{ arm = character:FindFirstChild("LeftLowerArm") or leftArm, sign = -1, name = "Left" },
			{ arm = character:FindFirstChild("RightLowerArm") or rightArm, sign = 1, name = "Right" },
		}
		for _, data in ipairs(armList) do
			if data.arm then
				local bracer = makePart(pauldrons, data.name .. "Bracer", Vector3.new(0.74, 0.55, 0.74), Color3.fromRGB(115, 75, 42), Enum.Material.Fabric)
				bracer.CFrame = data.arm.CFrame * CFrame.new(0, -0.2, 0)
				weldParts(data.arm, bracer)

				local trim = makePart(pauldrons, data.name .. "Trim", Vector3.new(0.78, 0.12, 0.78), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
				trim.CFrame = data.arm.CFrame * CFrame.new(0, -0.05, 0)
				weldParts(data.arm, trim)
			end
		end

	elseif armsId == "RockhideWraps" then
		-- Mage Boss Wraps (Tremor-Bound Drake-Hide Wraps)
		local armList = {
			{ arm = character:FindFirstChild("LeftLowerArm") or leftArm, upperArm = leftArm, sign = -1, name = "Left" },
			{ arm = character:FindFirstChild("RightLowerArm") or rightArm, upperArm = rightArm, sign = 1, name = "Right" },
		}
		for _, data in ipairs(armList) do
			if data.arm then
				-- Dark hide wrap base
				local wrap = makePart(pauldrons, data.name .. "Wrap", Vector3.new(0.78, 0.70, 0.78), Color3.fromRGB(36, 26, 18), Enum.Material.Fabric)
				wrap.CFrame = data.arm.CFrame * CFrame.new(0, -0.18, 0)
				weldParts(data.arm, wrap)

				-- Front stone forearm plate
				local stonePlate = makePart(pauldrons, data.name .. "StonePlate", Vector3.new(0.48, 0.46, 0.20), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
				stonePlate.CFrame = data.arm.CFrame * CFrame.new(0, -0.18, -0.42)
				weldParts(data.arm, stonePlate)

				-- Glowing rune cuff band (top of bracer)
				local runeCuff = makePart(pauldrons, data.name .. "RuneCuff", Vector3.new(0.82, 0.09, 0.82), Color3.fromRGB(255, 115, 25), Enum.Material.Neon)
				runeCuff.CFrame = data.arm.CFrame * CFrame.new(0, 0.08, 0)
				weldParts(data.arm, runeCuff)

				-- Glowing magma vein on plate
				local magmaVein = makePart(pauldrons, data.name .. "MagmaVein", Vector3.new(0.10, 0.36, 0.10), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
				magmaVein.CFrame = data.arm.CFrame * CFrame.new(0, -0.18, -0.45)
				addMesh(magmaVein, Enum.MeshType.Sphere, Vector3.new(0.6, 1, 0.6))
				weldParts(data.arm, magmaVein)

				-- Stone plate glow
				local plateLight = Instance.new("PointLight")
				plateLight.Color = Color3.fromRGB(255, 100, 20)
				plateLight.Range = 4
				plateLight.Brightness = 1.0
				plateLight.Parent = magmaVein

				-- Shoulder upper guard (stone cap on upper arm)
				if data.upperArm then
					local shoulderCap = makePart(pauldrons, data.name .. "ShoulderCap", Vector3.new(0.88, 0.32, 0.88), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
					shoulderCap.CFrame = data.upperArm.CFrame * CFrame.new(data.sign * 0.10, 0.36, 0) * CFrame.Angles(0, 0, data.sign * math.rad(12))
					addMesh(shoulderCap, Enum.MeshType.Sphere, Vector3.new(1.1, 0.56, 1.1))
					weldParts(data.upperArm, shoulderCap)

					-- Small stone spike on shoulder
					local spike = makePart(pauldrons, data.name .. "ShoulderSpike", Vector3.new(0.16, 0.42, 0.16), Color3.fromRGB(24, 20, 16), Enum.Material.Slate)
					spike.CFrame = data.upperArm.CFrame * CFrame.new(data.sign * 0.18, 0.64, 0) * CFrame.Angles(0, 0, data.sign * math.rad(-20))
					addMesh(spike, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.4, 0.8))
					weldParts(data.upperArm, spike)

					local spikeTip = makePart(pauldrons, data.name .. "SpikeTip", Vector3.new(0.09, 0.16, 0.09), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
					spikeTip.CFrame = data.upperArm.CFrame * CFrame.new(data.sign * 0.28, 0.90, 0) * CFrame.Angles(0, 0, data.sign * math.rad(-22))
					addMesh(spikeTip, Enum.MeshType.Pyramid, Vector3.new(0.7, 1.3, 0.7))
					weldParts(data.upperArm, spikeTip)
				end
			end
		end
	end

	pauldrons.Parent = character
end

local function attachBoots(character: Model, feetId: string?)
	local existing = character:FindFirstChild("EquippedBoots")
	if existing then existing:Destroy() end
	if not feetId then return end

	local leftLeg = character:FindFirstChild("LeftFoot") or character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("Left Leg")
	local rightLeg = character:FindFirstChild("RightFoot") or character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("Right Leg")
	if not leftLeg and not rightLeg then return end

	local boots = Instance.new("Model")
	boots.Name = "EquippedBoots"

	if feetId == "RockhideFeet" then
		-- Monster Hunter Tri-Claw Wyvern Beast Sabatons
		local legList = {
			{leg = leftLeg, name = "Left"},
			{leg = rightLeg, name = "Right"},
		}
		for _, data in ipairs(legList) do
			if data.leg then
				-- 1. Articulated Segmented Basalt Shin Greave (Upper & Lower)
				local upperGreave = makePart(boots, data.name .. "UpperGreave", Vector3.new(0.86, 0.52, 0.26), Color3.fromRGB(36, 32, 28), Enum.Material.Slate)
				upperGreave.CFrame = data.leg.CFrame * CFrame.new(0, 0.22, -0.42)
				weldParts(data.leg, upperGreave)

				local lowerGreave = makePart(boots, data.name .. "LowerGreave", Vector3.new(0.82, 0.48, 0.24), Color3.fromRGB(42, 38, 34), Enum.Material.Slate)
				lowerGreave.CFrame = data.leg.CFrame * CFrame.new(0, -0.15, -0.44)
				weldParts(data.leg, lowerGreave)

				-- Dual leather calf straps
				for _, yPos in {0.30, -0.10} do
					local strap = makePart(boots, data.name .. "CalfStrap_" .. yPos, Vector3.new(0.88, 0.12, 0.88), Color3.fromRGB(48, 34, 24), Enum.Material.Fabric)
					strap.CFrame = data.leg.CFrame * CFrame.new(0, yPos, 0)
					weldParts(data.leg, strap)
				end

				-- 2. Faceted Rock Knee Poleyn & Forward Barb
				local poleyn = makePart(boots, data.name .. "KneePoleyn", Vector3.new(0.78, 0.38, 0.35), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
				poleyn.CFrame = data.leg.CFrame * CFrame.new(0, 0.46, -0.45)
				addMesh(poleyn, Enum.MeshType.Wedge)
				weldParts(data.leg, poleyn)

				local kneeBarb = makePart(boots, data.name .. "KneeBarb", Vector3.new(0.28, 0.45, 0.36), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
				kneeBarb.CFrame = data.leg.CFrame * CFrame.new(0, 0.52, -0.52) * CFrame.Angles(math.rad(28), 0, 0)
				addMesh(kneeBarb, Enum.MeshType.Pyramid)
				weldParts(data.leg, kneeBarb)

				-- 3. Basalt Foot Housing
				local footHousing = makePart(boots, data.name .. "FootHousing", Vector3.new(0.88, 0.38, 0.82), Color3.fromRGB(38, 34, 30), Enum.Material.Slate)
				footHousing.CFrame = data.leg.CFrame * CFrame.new(0, -0.42, -0.12)
				addMesh(footHousing, Enum.MeshType.Sphere, Vector3.new(1.0, 0.75, 1.1))
				weldParts(data.leg, footHousing)

				-- 4. Tri-Claw Wyvern Beast Talons (Center, Left, Right)
				local centerClaw = makePart(boots, data.name .. "CenterClaw", Vector3.new(0.24, 0.32, 0.48), Color3.fromRGB(22, 18, 16), Enum.Material.Slate)
				centerClaw.CFrame = data.leg.CFrame * CFrame.new(0, -0.46, -0.55) * CFrame.Angles(math.rad(18), 0, 0)
				addMesh(centerClaw, Enum.MeshType.Pyramid, Vector3.new(0.85, 1.3, 1.2))
				weldParts(data.leg, centerClaw)

				local leftClaw = makePart(boots, data.name .. "LeftClaw", Vector3.new(0.20, 0.28, 0.42), Color3.fromRGB(22, 18, 16), Enum.Material.Slate)
				leftClaw.CFrame = data.leg.CFrame * CFrame.new(-0.28, -0.46, -0.50) * CFrame.Angles(math.rad(18), math.rad(-14), 0)
				addMesh(leftClaw, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.2, 1.1))
				weldParts(data.leg, leftClaw)

				local rightClaw = makePart(boots, data.name .. "RightClaw", Vector3.new(0.20, 0.28, 0.42), Color3.fromRGB(22, 18, 16), Enum.Material.Slate)
				rightClaw.CFrame = data.leg.CFrame * CFrame.new(0.28, -0.46, -0.50) * CFrame.Angles(math.rad(18), math.rad(14), 0)
				addMesh(rightClaw, Enum.MeshType.Pyramid, Vector3.new(0.8, 1.2, 1.1))
				weldParts(data.leg, rightClaw)

				-- 5. Backward Stone Heel Spur
				local spur = makePart(boots, data.name .. "Spur", Vector3.new(0.24, 0.24, 0.48), Color3.fromRGB(24, 20, 18), Enum.Material.Slate)
				spur.CFrame = data.leg.CFrame * CFrame.new(0, -0.38, 0.56) * CFrame.Angles(math.rad(-18), 0, 0)
				addMesh(spur, Enum.MeshType.Pyramid, Vector3.new(0.8, 0.8, 1.3))
				weldParts(data.leg, spur)

				-- 6. Glowing Subterranean Magma Tremor Sole
				local glow = makePart(boots, data.name .. "TremorPlate", Vector3.new(0.78, 0.12, 0.72), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
				glow.CFrame = data.leg.CFrame * CFrame.new(0, -0.05, -0.22)
				addMesh(glow, Enum.MeshType.Sphere, Vector3.new(1.0, 0.35, 1.0))
				weldParts(data.leg, glow)
			end
		end

	elseif feetId == "StandardFeet" then
		-- Standard Adventurer Iron Greaves & Sabatons
		local legList = {
			{leg = leftLeg, name = "Left"},
			{leg = rightLeg, name = "Right"},
		}
		for _, data in ipairs(legList) do
			if data.leg then
				-- 1. Contoured Iron Shin Greave
				local greave = makePart(boots, data.name .. "Greave", Vector3.new(0.68, 0.82, 0.14), Color3.fromRGB(115, 120, 130), Enum.Material.Metal)
				greave.CFrame = data.leg.CFrame * CFrame.new(0, 0.04, -0.42)
				weldParts(data.leg, greave)

				-- 2. Leather Calf Straps (Upper and Lower)
				local upperStrap = makePart(boots, data.name .. "UpperCalfStrap", Vector3.new(0.74, 0.10, 0.84), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
				upperStrap.CFrame = data.leg.CFrame * CFrame.new(0, 0.28, 0)
				weldParts(data.leg, upperStrap)

				local lowerStrap = makePart(boots, data.name .. "LowerCalfStrap", Vector3.new(0.74, 0.10, 0.84), Color3.fromRGB(58, 42, 28), Enum.Material.Fabric)
				lowerStrap.CFrame = data.leg.CFrame * CFrame.new(0, -0.18, 0)
				weldParts(data.leg, lowerStrap)

				-- 3. Sturdy Iron Sabaton Toe Cap
				local sabaton = makePart(boots, data.name .. "Sabaton", Vector3.new(0.74, 0.24, 0.58), Color3.fromRGB(115, 120, 130), Enum.Material.Metal)
				sabaton.CFrame = data.leg.CFrame * CFrame.new(0, -0.44, -0.16)
				addMesh(sabaton, Enum.MeshType.Sphere, Vector3.new(1.0, 0.60, 1.0))
				weldParts(data.leg, sabaton)

				-- 4. Adventurer Boot Sole
				local sole = makePart(boots, data.name .. "BootSole", Vector3.new(0.76, 0.14, 0.82), Color3.fromRGB(42, 32, 24), Enum.Material.Fabric)
				sole.CFrame = data.leg.CFrame * CFrame.new(0, -0.50, 0.05)
				weldParts(data.leg, sole)
			end
		end

	elseif feetId == "ApprenticeBoots" then
		-- Mage Starter Treads (Soft leather traveling boots with gold ankle buckle)
		local legList = {
			{leg = leftLeg, name = "Left"},
			{leg = rightLeg, name = "Right"},
		}
		for _, data in ipairs(legList) do
			if data.leg then
				local boot = makePart(boots, data.name .. "Tread", Vector3.new(0.72, 0.65, 0.80), Color3.fromRGB(50, 36, 26), Enum.Material.Fabric)
				boot.CFrame = data.leg.CFrame * CFrame.new(0, -0.22, 0)
				weldParts(data.leg, boot)

				local buckle = makePart(boots, data.name .. "Buckle", Vector3.new(0.20, 0.16, 0.12), Color3.fromRGB(215, 170, 55), Enum.Material.Metal)
				buckle.CFrame = data.leg.CFrame * CFrame.new(0, -0.15, -0.42)
				weldParts(data.leg, buckle)
			end
		end

	elseif feetId == "RockhideStriders" then
		-- ── Rockhide Earthstrider Sabatons (Volcanic Treads) ─────────────────
		local legList = {
			{leg = leftLeg, name = "Left"},
			{leg = rightLeg, name = "Right"},
		}
		for _, data in ipairs(legList) do
			if data.leg then
				-- Dark hide/leather boot base
				local boot = makePart(boots, data.name .. "Tread", Vector3.new(0.78, 0.72, 0.84), Color3.fromRGB(28, 22, 16), Enum.Material.Fabric)
				boot.CFrame = data.leg.CFrame * CFrame.new(0, -0.20, 0)
				weldParts(data.leg, boot)

				-- Upper shin stone guard
				local upperShin = makePart(boots, data.name .. "UpperShin", Vector3.new(0.56, 0.36, 0.20), Color3.fromRGB(34, 30, 26), Enum.Material.Slate)
				upperShin.CFrame = data.leg.CFrame * CFrame.new(0, 0.18, -0.44)
				weldParts(data.leg, upperShin)

				-- Lower shin stone guard
				local lowerShin = makePart(boots, data.name .. "LowerShin", Vector3.new(0.52, 0.32, 0.18), Color3.fromRGB(38, 34, 30), Enum.Material.Cobblestone)
				lowerShin.CFrame = data.leg.CFrame * CFrame.new(0, -0.08, -0.44)
				weldParts(data.leg, lowerShin)

				-- Glowing rune ankle band
				local runeAnkle = makePart(boots, data.name .. "RuneAnkle", Vector3.new(0.82, 0.09, 0.86), Color3.fromRGB(255, 115, 25), Enum.Material.Neon)
				runeAnkle.CFrame = data.leg.CFrame * CFrame.new(0, -0.30, 0)
				weldParts(data.leg, runeAnkle)

				-- Stone toe cap
				local toeCap = makePart(boots, data.name .. "ToeCap", Vector3.new(0.68, 0.22, 0.54), Color3.fromRGB(32, 28, 24), Enum.Material.Slate)
				toeCap.CFrame = data.leg.CFrame * CFrame.new(0, -0.46, -0.18)
				addMesh(toeCap, Enum.MeshType.Sphere, Vector3.new(1.0, 0.55, 1.0))
				weldParts(data.leg, toeCap)

				-- Glowing lava tremor sole
				local tremorSole = makePart(boots, data.name .. "TremorSole", Vector3.new(0.80, 0.12, 0.86), Color3.fromRGB(255, 105, 20), Enum.Material.Neon)
				tremorSole.CFrame = data.leg.CFrame * CFrame.new(0, -0.56, 0.04)
				weldParts(data.leg, tremorSole)

				-- Sole glow light
				local soleLight = Instance.new("PointLight")
				soleLight.Color = Color3.fromRGB(255, 100, 20)
				soleLight.Range = 5
				soleLight.Brightness = 1.2
				soleLight.Parent = tremorSole

				-- Ground ember particle from sole
				local soleEmitter = Instance.new("ParticleEmitter")
				soleEmitter.Name = "SoleEmbers"
				soleEmitter.LightEmission = 1
				soleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 5)),
				})
				soleEmitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.07),
					NumberSequenceKeypoint.new(0.6, 0.04),
					NumberSequenceKeypoint.new(1, 0),
				})
				soleEmitter.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.0),
					NumberSequenceKeypoint.new(0.7, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				})
				soleEmitter.SpreadAngle = Vector2.new(120, 120)
				soleEmitter.Speed = NumberRange.new(0.3, 1.0)
				soleEmitter.Rate = 5
				soleEmitter.Lifetime = NumberRange.new(0.5, 1.0)
				soleEmitter.Parent = tremorSole

				-- Small lava crack on shin
				local shinCrack = makePart(boots, data.name .. "ShinCrack", Vector3.new(0.06, 0.28, 0.06), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
				shinCrack.CFrame = data.leg.CFrame * CFrame.new(0, 0.05, -0.47)
				addMesh(shinCrack, Enum.MeshType.Sphere, Vector3.new(0.5, 1, 0.5))
				weldParts(data.leg, shinCrack)
			end
		end
	end

	boots.Parent = character
end

function WeaponService.EquipWeapons(character: Model, weaponSetId: string?, shieldSetId: string?)
	if not character or not character.Parent then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	local profile = player and (PlayerDataService.GetProfile(player) or PlayerDataService.WaitForProfile(player))
	local charData = profile and profile.Data.Character

	local classId = (charData and charData.ClassId) or "Mage"
	local isMage = (classId == "Mage")

	local equipped = charData and charData.EquippedEquipment or {}
	local targetWeapon = weaponSetId or equipped.Weapon or (charData and charData.EquippedWeapon) or (isMage and "ApprenticeStaff" or "StandardSword")
	local targetArms = shieldSetId or equipped.Arms or (isMage and "ApprenticeBracers" or "StandardArms")
	local targetHead = equipped.Head or (isMage and "ApprenticeHood" or "StandardHelm")
	local targetBody = equipped.Body or (isMage and "ApprenticeRobe" or "StandardChest")
	local targetFeet = equipped.Feet or (isMage and "ApprenticeBoots" or "StandardFeet")

	-- If character is Mage, sanitize any Tank gear to Mage equivalents
	if isMage then
		if targetWeapon == "StandardSword" or targetWeapon == "Standard" then
			targetWeapon = "ApprenticeStaff"
		elseif targetWeapon == "RockhideFang" or targetWeapon == "Rockhide" then
			targetWeapon = "RockhideStaff"
		end

		if targetHead == "StandardHelm" then
			targetHead = "ApprenticeHood"
		elseif targetHead == "RockhideHelm" then
			targetHead = "RockhideCowl"
		end

		if targetBody == "StandardChest" then
			targetBody = "ApprenticeRobe"
		elseif targetBody == "RockhideChest" then
			targetBody = "RockhideRobes"
		end

		if targetArms == "StandardArms" then
			targetArms = "ApprenticeBracers"
		elseif targetArms == "RockhideArms" then
			targetArms = "RockhideWraps"
		end

		if targetFeet == "StandardFeet" then
			targetFeet = "ApprenticeBoots"
		elseif targetFeet == "RockhideFeet" then
			targetFeet = "RockhideStriders"
		end

		-- Keep profile data in sync
		if charData and charData.EquippedEquipment then
			charData.EquippedEquipment.Weapon = targetWeapon
			charData.EquippedEquipment.Head = targetHead
			charData.EquippedEquipment.Body = targetBody
			charData.EquippedEquipment.Arms = targetArms
			charData.EquippedEquipment.Feet = targetFeet
			charData.EquippedWeapon = targetWeapon
		end
	end

	-- Clean up existing models if re-equipping / swapping
	local existingSword = character:FindFirstChild("EquippedSword")
	if existingSword then existingSword:Destroy() end
	local existingShield = character:FindFirstChild("EquippedShield")
	if existingShield then existingShield:Destroy() end
	local existingHelm = character:FindFirstChild("EquippedHelm")
	if existingHelm then existingHelm:Destroy() end
	local existingChest = character:FindFirstChild("EquippedChest")
	if existingChest then existingChest:Destroy() end
	local existingPauldrons = character:FindFirstChild("EquippedPauldrons")
	if existingPauldrons then existingPauldrons:Destroy() end
	local existingBoots = character:FindFirstChild("EquippedBoots")
	if existingBoots then existingBoots:Destroy() end

	-- Attach 3D Visual Armor across all slots
	attachHelm(character, targetHead)
	attachChest(character, targetBody)
	attachPauldrons(character, targetArms)
	attachBoots(character, targetFeet)

	-- Apply gear MaxHealth bonus dynamically to Humanoid
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local classDef = Classes[classId] or Classes.Mage
		local baseMaxHP = classDef.baseHealth or 100
		local hpBonus = 0
		local equippedList = {targetWeapon, targetHead, targetBody, targetArms, targetFeet}
		for _, pieceId in ipairs(equippedList) do
			local itm = EquipmentData.Items[pieceId]
			if itm and itm.stats and itm.stats.maxHPBonus then
				hpBonus += itm.stats.maxHPBonus
			end
		end
		local targetMaxHP = baseMaxHP + hpBonus
		if humanoid.MaxHealth ~= targetMaxHP then
			local currentRatio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
			humanoid.MaxHealth = targetMaxHP
			humanoid.Health = math.clamp(math.round(targetMaxHP * currentRatio), 1, targetMaxHP)
		end
		if player then
			Net.Get("HealthChanged"):FireAllClients(player.UserId, humanoid.Health, humanoid.MaxHealth)
		end
	end

	-- Identify right and left arm/hand parts for R15 or R6
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")

	if not rightHand or not leftHand then
		task.spawn(function()
			local rh = character:WaitForChild("RightHand", 4) or character:WaitForChild("Right Arm", 2)
			local lh = character:WaitForChild("LeftHand", 4) or character:WaitForChild("Left Arm", 2)
			if rh and lh and not character:FindFirstChild("EquippedSword") then
				WeaponService.EquipWeapons(character)
			end
		end)
		return
	end

	-- Remove any old grip motors to ensure clean attach
	local oldSwordGrip = rightHand:FindFirstChild("SwordGrip")
	if oldSwordGrip then oldSwordGrip:Destroy() end
	local oldShieldGrip = leftHand:FindFirstChild("ShieldGrip")
	if oldShieldGrip then oldShieldGrip:Destroy() end

	-- 1. Equip Weapon (Sword or Focus Staff)
	local weaponModel, weaponHandle = createWeaponModel(targetWeapon)
	local weaponGrip = Instance.new("Motor6D")
	weaponGrip.Name = "SwordGrip"
	weaponGrip.Part0 = rightHand
	weaponGrip.Part1 = weaponHandle
	if targetWeapon == "ApprenticeStaff" or targetWeapon == "RockhideStaff" then
		weaponGrip.C0 = CFrame.new(0, -0.35, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	else
		weaponGrip.C0 = CFrame.new(0, -0.4, -0.2) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))
	end
	weaponGrip.Parent = rightHand
	weaponModel.Parent = character

	-- 2. Equip Shield (Tank only; Mages do not carry shields)
	if not isMage and targetWeapon ~= "ApprenticeStaff" and targetWeapon ~= "RockhideStaff" then
		local shieldModel, shieldHandle = createShieldModel(targetArms, targetWeapon)
		if shieldModel and shieldHandle then
			local shieldGrip = Instance.new("Motor6D")
			shieldGrip.Name = "ShieldGrip"
			shieldGrip.Part0 = leftHand
			shieldGrip.Part1 = shieldHandle
			shieldGrip.C0 = CFrame.new(-0.35, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
			shieldGrip.Parent = leftHand
			shieldModel.Parent = character
		end
	end

	-- Sync equipment state to client
	if player and charData then
		Net.Get("EquipmentDataChanged"):FireClient(
			player,
			charData.EquippedEquipment or {
				Weapon = isMage and "ApprenticeStaff" or "StandardSword",
				Head = isMage and "ApprenticeHood" or "StandardHelm",
				Body = isMage and "ApprenticeRobe" or "StandardChest",
				Arms = isMage and "ApprenticeBracers" or "StandardArms",
				Feet = isMage and "ApprenticeBoots" or "StandardFeet",
			},
			charData.StoredEquipment or {},
			charData.CraftingMaterials or {}
		)
	end
end

function WeaponService.Start()
	-- Handle equipment change requests from client (for crafting / swapping individual gear pieces)
	Net.Get("RequestEquipEquipment").OnServerEvent:Connect(function(player: Player, itemId: string)
		local profile = PlayerDataService.GetProfile(player)
		local charData = profile and profile.Data.Character
		if not charData then
			return
		end

		local item = EquipmentData.Items[itemId]
		if not item then
			return
		end

		-- Validate class eligibility: Mages cannot equip Tank gear, Tanks cannot equip Mage gear
		local itemClass = EquipmentData.GetItemClass(itemId)
		local playerClass = charData.ClassId or "Mage"
		if itemClass and itemClass ~= playerClass then
			warn(string.format("WeaponService: %s (%s) cannot equip %s (requires %s)", player.Name, tostring(playerClass), itemId, itemClass))
			return
		end

		-- Validate ownership in stored equipment
		local hasOwned = false
		for _, ownedId in ipairs(charData.StoredEquipment or {}) do
			if ownedId == itemId then
				hasOwned = true
				break
			end
		end

		if hasOwned then
			if not charData.EquippedEquipment then
				local isMage = (playerClass == "Mage")
				charData.EquippedEquipment = {
					Weapon = isMage and "ApprenticeStaff" or "StandardSword",
					Head = isMage and "ApprenticeHood" or "StandardHelm",
					Body = isMage and "ApprenticeRobe" or "StandardChest",
					Arms = isMage and "ApprenticeBracers" or "StandardArms",
					Feet = isMage and "ApprenticeBoots" or "StandardFeet",
				}
			end
			charData.EquippedEquipment[item.slot] = itemId
			if item.slot == "Weapon" then
				charData.EquippedWeapon = itemId
			end
			if player.Character then
				WeaponService.EquipWeapons(player.Character)
			end
		end
	end)

	local function onCharacter(character: Model)
		task.wait(0.2)
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			local profile = PlayerDataService.GetProfile(player)
			if not profile then
				task.spawn(function()
					PlayerDataService.WaitForProfile(player)
					if character and character.Parent then
						WeaponService.EquipWeapons(character)
					end
				end)
				return
			end
		end
		WeaponService.EquipWeapons(character)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return WeaponService
