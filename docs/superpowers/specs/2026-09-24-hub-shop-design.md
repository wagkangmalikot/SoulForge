# Hub Shop: Health Potions

**Date:** 2026-09-24
**Status:** Approved

Adds a shopkeeper in the Hub plaza where players spend Gold on Health Potions before heading into a dungeon raid, plus a HUD quick-use slot to drink them mid-run.

## Problem

The game has Gold (`charData.Gold`, currently kept effectively unlimited for testing, same as `CraftingMaterials`) with nothing to spend it on beyond crafting gear. There is no consumable-item system at all, and no in-combat recovery option besides class skills (`selfHeal`/`healTarget`/`aoeHeal`) and the existing downed/revive loop (`RespawnService`). Players have no way to buy a safety net before a raid or recover mid-fight without a Healer in the party.

## Design

### 1. Data: `Consumables.lua`

New file `src/ReplicatedStorage/Shared/Data/Consumables.lua`, shaped like `Skills.lua` (a flat table keyed by item id):

```lua
return {
	MinorHealthPotion = {
		id = "MinorHealthPotion",
		displayName = "Minor Health Potion",
		icon = "rbxasset://textures/Soulforge/minor_health_potion_icon.png",
		description = "A watered-down restorative. Heals 25% of max health.",
		healPercent = 0.25,
		price = 20,
		tier = 1,
	},
	HealthPotion = {
		id = "HealthPotion",
		displayName = "Health Potion",
		icon = "rbxasset://textures/Soulforge/health_potion_icon.png",
		description = "A proper alchemical brew. Heals 50% of max health.",
		healPercent = 0.50,
		price = 50,
		tier = 2,
	},
	GreaterHealthPotion = {
		id = "GreaterHealthPotion",
		displayName = "Greater Health Potion",
		icon = "rbxasset://textures/Soulforge/greater_health_potion_icon.png",
		description = "A masterwork elixir. Fully restores health.",
		healPercent = 1.00,
		price = 120,
		tier = 3,
	},
}
```

Owned counts live in `charData.Consumables = {[itemId]: count}`, added to `PlayerDataService.lua`'s `DEFAULT_DATA.Character` next to `CraftingMaterials`, with the same per-key backfill treatment in the existing migration block (`charData.Consumables = charData.Consumables or {}`, no forced `math.max` top-up since owned potions are earned/bought, not a dev convenience like the materials/gold floor).

### 2. Server: `ShopService.lua`

Mirrors `CraftingService.lua`'s split exactly: server owns Gold and Consumables truth, client is a dumb renderer.

- `ShopService.Start()` wires two remotes:
  - `RequestBuyPotion(itemId)`: validates `Consumables[itemId]` exists, `charData.Gold >= price`; deducts gold, increments `charData.Consumables[itemId]`; fires `ShopResult(success, message, newGold, newConsumables)` back to that client.
  - `RequestUsePotion(itemId)`: validates owned count > 0, not on cooldown (server-tracked `lastPotionUseAt[userId]`, 12s, mirroring `CombatService`'s `lastCastAt` pattern so a client can't bypass it), player has a `Humanoid` and isn't already at full health and isn't downed (`RespawnService.IsPlayerDowned`, same guard `CombatService.onCastSkill` uses for skills). On success: `humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * item.healPercent)`, decrement count, fire the existing `HealthChanged` remote (same one `CombatService`/`selfHeal` already use) and a new `PotionUseResult(success, message, newConsumables)`.
- No new heal-multiplier interaction with `RockhideHealer`'s "Earthen Blessing" set bonus -- that bonus is caster-side (healing *others*), potions are self-use only, out of scope.

### 3. Client: `ShopUIController.lua`

Same shape as `CraftingUIController.lua`: builds a buy-screen panel (three potion rows, each showing icon/name/description/price/owned-count/a Buy button disabled when `Gold < price`), listens for `OpenShopUI` (opens panel), `ShopResult` (updates gold display, owned counts, re-renders), and `EquipmentDataChanged`-style gold sync is unnecessary since Gold already isn't broadcast separately anywhere else -- `ShopResult`'s `newGold` is the only place the client's gold display needs to come from besides the HUD's existing gold readout, if the HUD shows one today (it doesn't currently -- Gold is inventory-screen-only per `InventoryUIController`'s `9,999,999 GOLD` display, so the Shop panel gets its own gold readout, fed by `ShopResult` and refreshed via a new lightweight `RequestGoldSync`/`GoldSynced` remote pair fired once on panel open, matching how `RequestCharacterState` works for character data).

### 4. Hub placement: shopkeeper prop + prompt

`HubMapService.lua` gets a new `makeShopkeeperStall(parent, position, ...)` builder (hand-placed parts/meshes via the existing `makePart`/`addMesh`/`makeCylinder`/`makeWedge` helpers, no procedural-mesh generation, matching every other Hub landmark) placed near the fountain plaza alongside the crafting anvil. Two viable prompt patterns exist in this codebase (server-attached like the anvil, or client-attached like the portals/shrine) -- this uses the **client-attached** pattern to match `DungeonPortalController`/`LevelUpUIController`, since opening a UI panel is a pure client concern and every other UI-opening prompt in the game already works this way:

```lua
-- ShopController.lua (new, StarterPlayerScripts/Controllers)
task.spawn(function()
	local stallPart = workspace:WaitForChild("ShopkeeperStall")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse Wares"
	prompt.ObjectText = "Shopkeeper"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.Parent = stallPart
	prompt.Triggered:Connect(function()
		ShopUIController.Open()
	end)
end)
```

Same hub-only guard every other Hub-only controller uses (`IsDungeon` attribute check / `TeleportService:GetLocalPlayerTeleportData()`).

### 5. HUD quick-use slot

`HUDController.lua` gains one more slot following the exact `SkillSlot_i` construction pattern (frame, icon, name-plate, `CooldownLabel`, `DimOverlay`, invisible hit-`TextButton`) but keyed to Consumables instead of `equippedSkills` -- a fixed `PotionSlot` showing the currently-highest-tier owned potion's icon and an owned-count badge (new label, since skill slots don't need one). Clicking it fires `RequestUsePotion` with that potion's id. The same `RunService.Heartbeat` loop `HUDController` already runs for skill cooldowns extends to also check a `potionCooldownEndsAt` timestamp and dim/count-down this slot -- no second Heartbeat connection needed. If the player owns multiple tiers, "highest-tier owned" is a deliberate simplification (spend the best potion first is backwards for players who want to save Greater potions for tougher fights, but a tier-picker adds real UI complexity for a first pass); flagged in Constraints below as a known simplification, not silently decided.

### 6. Net.lua remotes

Six new entries appended to `REMOTE_NAMES`, matching the existing comment style. No `OpenShopUI` remote -- per the client-attached prompt pattern chosen in §4, `ShopController` opens the panel directly client-side (same as `DungeonPortalController`/`LevelUpUIController`), so no server round-trip is needed just to open it:

```lua
"RequestBuyPotion",   -- client -> server: {itemId} -- request to purchase a potion
"ShopResult",         -- server -> client: {success, message, newGold, newConsumables}
"RequestUsePotion",   -- client -> server: {itemId} -- request to drink an owned potion
"PotionUseResult",    -- server -> client: {success, message, newConsumables}
"RequestGoldSync",    -- client -> server: () -- ask for current gold on shop panel open
"GoldSynced",         -- server -> client: {gold} -- reply to RequestGoldSync
```

## Constraints

- Health potions only -- no mana potions, since there's no mana resource in this game yet (skills are cooldown-gated, not resource-gated). Revisit if a mana system is ever added.
- HUD quick-use slot always drinks the highest-tier owned potion; no in-HUD tier picker. A player who wants to save Greater potions must simply not buy/hold Minor ones, or use the (not-yet-built) Inventory-side use option if one is added later.
- No stack cap enforced -- consistent with `CraftingMaterials` already having no cap in this dev-mode-gold build. Revisit alongside any future real-economy pass.
- Shop is Hub-only (can't buy mid-dungeon); using already-owned potions works anywhere (Hub or dungeon), same as skills.
- Does not touch `RockhideHealer`'s "Earthen Blessing" set bonus, `RespawnService`'s downed/revive loop, or any class skill -- potions are a fully separate, self-use-only recovery path.

## Suggested future shop additions

Not built now -- flagged per your request for ideas on what else the shop could eventually sell, roughly in order of how well they fit the existing systems:

- **Crafting materials for Gold** (`IronIngot`, `OakTimber`, etc.) -- lets players buy their way past a material shortfall instead of only farming; trivial to add once Gold stops being unlimited-for-testing, since `CraftingService` already has the deduct/validate plumbing this would reuse.
- **Respec token** -- the skill tree already has a "RESPEC" button (seen live during Healer verification); if it's currently free, gating a *full* tree reset behind a Gold cost (vs. the existing per-node behavior, whatever that turns out to be) is a natural shop item once its current mechanics are confirmed.
- **Revive token** -- an item usable on a downed ally to skip `RespawnService`'s wait-for-ally-or-timer loop instantly; ties into the existing downed system with no new mechanic, just a new trigger path.
- **Temporary raid buffs** -- e.g. a "+10% EXP for this raid" or "+10% Gold for this raid" scroll, consumed on dungeon entry; would need a small buff-state addition to `DungeonSessionService`'s reward calculation (`expBase`/`goldBase` in the reward code already resolved this session).
- **Cosmetic dyes/outfits** -- biggest lift of this list; no cosmetic-override system exists today, would need its own design pass entirely separate from this one.

## Out of scope

- A mana system (see Constraints).
- In-dungeon shop access.
- Inventory-screen potion use (HUD-only for this pass).
- Any of the "Suggested future shop additions" above.
- Rebalancing Gold's current unlimited-for-testing state.
