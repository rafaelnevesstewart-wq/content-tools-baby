# Grow a Titan

A Roblox game. You hatch a titan, a giant gentle creature, and its back is your base. Feed it to make it grow. The whole server's titans walk together as one herd across four biomes. During the day you can board other titans to steal eggs and Riders. At night the herd has to team up and survive against beasts.

This repo holds the first playable build: one full day and night loop with every core system working, built from simple parts so it runs without any imported art.

## What's in this build

| System | Where |
|---|---|
| Titans that grow in 6 stages (Hatchling to Ancient) and physically carry players on their backs. Dark stone skin, glowing slit eyes, horned brows, jaws with teeth, steaming nostrils, claws, scars and a spiked tail, plus species features (ridge spikes, thorny moss, tusks) | `src/server/Services/TitanService.luau` |
| Ladders on both sides of every titan, with a plank to the deck and a **Climb** button at the bottom | `TitanService` |
| 9 titan skins: 2 bought with coins, 6 with Robux (Candy Pop to Golden King) | `Config.Skins`, `PlayerService`, shop screen |
| Terrain map: mountains, foothills, lakes, lava pools, the town of Titan's Rest in the middle and an outpost in each biome | `src/server/Services/MapBuilder.luau` |
| The herd walks a loop through Fern Valley, Salt Flats, Aurora Tundra and Ember Wastes | `TitanService`, `WorldService` |
| Foraging food, digging up eggs, taming wild Riders | `WorldService` |
| Coins per second from Riders, mutations (Golden to Void), rarities, hatching | `PlayerService` |
| Molt (rebirth): permanent +15% coins, +1 Rider slot and a new mutation roll | `PlayerService` |
| Monsters: Gloomhounds, Thornbacks and Golems roam ahead of the herd by day and hunt in waves at Nightfall, with a Storm King boss every 5th night. Kills drop coins and food | `src/server/Services/MonsterService.luau`, `CycleService` |
| Weapons: Blade and Sling free, Crossbow, Cleaver and Spear for coins, Maul (shockwave) and Reaper (lifesteal) for Robux | `Config.Weapons`, `src/server/Services/CombatService.luau` |
| Spells on Z X C V B: Fireball, Chain Lightning, Frost Nova (attack), Shield and Heal (defence), each upgradable to level 5 | `Config.Spells`, `CombatService`, `src/client/Combat.client.luau` |
| Fighting XP and levels (up to 50): each kill gives XP, each level adds health, power and damage. Weak Gloomlings always prowl just outside town for a first fight | `PlayerService`, `MonsterService`, `Config.Leveling` |
| Health, power (mana for spells) and XP bars with your level and strength, plus an inventory (I) to see and equip your gear | `src/client/Vitals.client.luau` |
| Death: your body ragdolls and crumbles into smoke, a "You were slain" screen says who got you, then you rise again on your titan | `CombatService`, `Vitals.client.luau` |
| Combat feel: damage numbers, 12% critical hits, monsters flinch, flash and bleed, weapon swings with sounds, a red flash and camera shake when you're hurt, ground shake near walking titans, rain in storms | `CombatService`, `MonsterService`, `src/client/Effects.client.luau` |
| Quest Board in town: 3 quests at a time (hunt, forage, feed, chests, spells), fresh every 20 minutes, tracked on screen | `src/server/Services/QuestService.luau`, `Vitals.client.luau` |
| Treasure chests ahead of the herd: hold to open, the lid swings up, coins, food and XP spill out | `QuestService` |
| Balance: Robux buys time, style and sidegrade weapons. The strongest weapon (Kingslayer Greatsword) is free-to-play only, coin weapons unlock by level, and PvP rewards can't be farmed on the same player | `Config.luau` |
| PvP everywhere except the town safe zone, with kill rewards and a Kills leaderboard | `CombatService` |
| Upgrades at the Forge: Strength, Armor, Swiftness and the food Auto-Picker | `Config.Upgrades`, `PlayerService`, `WorldService` |
| Drive your titan: sit in the saddle on its back, W/S to walk and A/D to turn. Get off and it walks back to the herd | `TitanService`, `Combat.client.luau` |
| Town base with an Armory, Spell Shrine and Forge, plus a Travel menu (Base, My Titan, each biome outpost) | `MapBuilder`, `WorldService`, `Combat.client.luau` |
| Darker world: fog, heavy clouds, lightning, torches, dead trees, a Titan Roar at night and shared dawn loot | `CycleService`, `MapBuilder` |
| Stealing: Shell Lock, egg-only protection for small titans, Snatch Back, Leap between titans, Call Home for homesick Riders | `StealService` |
| Perks: Herd Bond, Mutation Resonance, Weathered, Homecoming, Guardian crown | spread across the services above |
| Shop: 7 game passes and 5 developer products with receipt handling | `ShopService`, `src/client/Hud.client.luau` |
| Saving with DataStores (a failed load never overwrites saved progress) | `DataService` |
| HUD: stats, day/night timer, buttons, toasts, shop screen | `src/client/Hud.client.luau` |

All numbers (prices, growth, timers, odds) are in `src/shared/Config.luau`.

## How to open it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/), both the command-line tool and the Studio plugin.
2. In this folder, run `rojo serve`.
3. Open a new Baseplate place in Studio, delete the default `Baseplate` part, and click **Connect** in the Rojo plugin.
4. Press **Play**. The map, your titan and the HUD are all built when the game starts.

When you test in Studio:
- The day/night cycle is shortened (75s day, 60s night) so you reach Nightfall quickly.
- Shop items whose `Id` is still `0` are granted for free, so you can try every pass and product.
- To test saving, turn on **Game Settings → Security → Enable Studio Access to API Services**.
- To test stealing, start a local server with 2+ players from **Test → Clients and Servers**.

## Controls (computer)

The mouse turns the camera and your character, over the shoulder with a crosshair. Left click attacks with your weapon (hold to keep attacking), right click aims, Z X C V B cast spells, 1-9 pick a weapon. Left Alt frees the cursor to click buttons. I opens items, P the shop, T travel. Phones and tablets keep the normal Roblox controls.

## Using real 3D creature models

Titans and monsters are built from parts by default. To make them look like ARK-style creatures, put 3D models (from the Creator Store, or made in Blender and imported with the 3D Importer) into **ServerStorage > CreatureModels** with these names:

| Name | Replaces |
|---|---|
| `Titan_Shellback`, `Titan_Mossback`, `Titan_Tuskhorn`, `Titan_Driftfin` (or `Titan` for all) | the titan's body |
| `Monster_Gloomling`, `Monster_Gloomhound`, `Monster_Thornback`, `Monster_Golem`, `Monster_StormKing` | that monster's body |

The game scales each model to fit, keeps the deck, ladders and saddle, and removes any scripts inside the model. If a model faces the wrong way, add a number attribute `YawDegrees` (for example 90 or 180) to it.

## Before publishing

1. Create each game pass and developer product on the Creator Hub, then paste its id into `Id` in `Config.luau`. Robux skins are developer products too.
2. Set the server size to 12 players or fewer (Game Settings), or raise `Herd.MaxLanes` in `Config.luau`. The map keeps its buildings clear of that many titan lanes.
3. Put the real day and night lengths back if you changed them. The live values are `DayLength` and `NightLength` in `Config.luau`.
4. Paid eggs and serums count as paid random items under Roblox policy, so their odds must be shown before purchase. None are sold in this build.

## Design doc

The full concept pitch, with research sources and the reasoning behind prices, lives in the project files at `concepts/grow-a-titan-concept.md`.
