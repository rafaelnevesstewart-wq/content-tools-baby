# Bottle a Storm: Bed Wars ⛈️🛏️

A Roblox **Bed Wars** game in a stormy sky world. Everything is built from code, including the
islands, the cloud beds and the storm kits, so it runs in Studio with no uploaded art.

**Looks:** the islands are real Roblox terrain (grass with swaying blades, a dirt layer, rugged
rock hanging underneath, mossy boulders), joined by rope-and-plank bridges, with branching
trees. Beds are wooden (posts, headboard, blanket, pillow), generators are stone pedestals with
glowing orbs, the Item Shop is a market stall with a shopkeeper, and armor has a chestplate
with a team emblem, pauldrons, a belt, shin guards and a plumed helmet. Swords, the bow,
arrows, pickaxes, axes, TNT, potions, apples and pearls are all detailed models
(`Modules/ItemModels`).

**Camera:** on PC the camera turns with the mouse (the mouse is locked to a crosshair in the
middle of the screen and you face where you look, over the shoulder). Opening any window frees
the mouse; press **Ctrl** (or hold **Alt**) to free it any time. Phones and controllers keep
the normal camera.

## How a match works

Everyone waits in the **lobby** on the big middle island. With 2+ players (1 in Studio) a
15-second countdown starts. In the lobby, players **vote for Solos, Duos or Squads** (team
size 1, 2 or 4); the most votes wins (no votes: solos with up to 4 players, duos with more).
**Parties** (👥 Party) always end up on the same team. Up to 8 teams. Every match is on a new
**map**: 🌿 Meadow, 🌋 Volcano, ❄️ Frozen, 🍭 Candy or 🌌 Space (ground, cliffs, props and a
color wash), never the same twice in a row. Each team gets a sky island with:

- a **cloud bed** at the back. While it stands, you respawn 5 seconds after a knockout.
  Enemies break it by holding **E** on it for 2.5 seconds, but only if they can see it, so wall
  it in with blocks. Once it's gone, your next knockout puts you out (you watch from the sky box).
- a **generator** making 🟠 Copper (fast) and ⚪ Silver (slow). Stand on it to pick them up.
  The middle island has 💎 Storm Crystal and ⚡ Lightning Core generators that speed up at 6
  and 12 minutes.
- an **Item Shop**: blocks (Cloud Wool, Wood Planks, Stone Bricks, Obsidian), swords (Stone,
  Iron, Diamond), a bow and arrows, armor (Chain, Iron, Diamond; kept when you respawn),
  ⛏️ pickaxes and 🪓 axes (4 tiers each; they break blocks much faster and drop one tier when
  you die), 🧨 Storm TNT (place it; 3 seconds later it blows up blocks, not Obsidian, and
  knocks people away), 🔥 Fireballs (throw; they break wool and launch enemies), potions
  (💨 Speed, 🦘 Jump, 👻 Invisibility for 30 seconds), Storm Apples (heal) and Wind Pearls
  (throw to teleport). The 💎 Team tab has team upgrades bought with Crystals: Sharp Blades,
  Reinforced Armor, Storm Forge, Healing Aura.

Everyone has 100 health and starts with a wood sword. Hits push people back; falling off counts
as a knockout. The last team standing wins. At 20 minutes every bed breaks (Sudden Death); at
30 minutes the team with the most players left wins. Then everyone goes back to the lobby.

**Match weather** (`WeatherEvents`): a few minutes into a match, and every few minutes after,
an event shakes things up for 90 seconds: ⛈️ Thunderstorm (generators 2x), 🌈 Rainbow Hour
(double Sparks), 🌬️ Windstorm (stronger knockback), 🌫️ Fog Night, 🌠 Meteor Shower (middle
generators 3x) or 🌙 Moon Gravity. The forecast TV in the lobby shows what's next.

## Kits

Every storm you own is a **kit**. Pick one in 🌪️ **Kits**: in a match it floats beside you with
your name and gives its power on **Shift**: Updraft, Blink Dash, Surf Boost, Cloud Jump, or
🕊️ Cloud Flight (Hurricane Hana, Typhoon Titan and Solar Flare Phoenix only). **Rarer kits
recharge faster** (Common 100% of the cooldown down to Cosmic 55%). Shiny variants (Charged,
Frozen, Golden...) just look cooler. New players get a Puffcloud.

Get kits from the 🏪 **Kit Market** (the Kit Shop restocks 6 kits every 5 minutes; Kit Crates
give a random one), the battle pass, the spin wheel, daily login rewards, holiday shops, codes,
and the lobby parkour (a free Epic kit once a day). Your **Kit Collection** (🎁 Rewards → Kits)
gives Sparks for each new kit and +5% match Sparks forever for every completed rarity row.

## Sparks and what they buy

Sparks come from matches: knockouts, final kills, breaking beds, winning, and just playing.
They're multiplied by VIP, your Style Bonus, Kit Collection rows, your group bonus, Admin
Abuse and Rainbow Hour (the HUD shows your current bonus). Spend them on cosmetics and kits.

## Levels, ranked, streaks and achievements

- **Level and prestige:** XP from every match (playing, knockouts, beds, wins). Each level
  pays Sparks and every 10th level a kit. At level 100 you **prestige**: back to level 1 with
  a new star color and ⚡5,000 (up to prestige 10).
- **Ranked:** matches with 2+ teams give rank points (win +30, loss -12, final kill +5, bed
  +8): 🥉 Bronze, 🥈 Silver, 🥇 Gold, 💠 Platinum, 💎 Diamond, 🔮 Master, 👑 Champion. A lobby
  board shows the top ranked players.
- **Win streaks:** win in a row for bonus Sparks (⚡50 per win in the streak, up to 500).
- Your level, rank and streak show above your head and in the HUD; Level, Wins and Kills are
  the player list columns.
- **Victory dances:** when your team wins, you dance your 💃 Victory Dance (Cheer, Wave, Point,
  Laugh, Groove, Spin Move, Robot) in a shower of confetti.
- **Achievements** (🎁 Rewards → 🏅 Goals): 28 goals for playing, winning, knockouts, beds,
  streaks, levels, ranks and collecting. Rewards (Sparks, kits and 3 achievement-only
  cosmetics: Champion Trail, Veteran Bed, Legend Strike) are given automatically.

## Cosmetics (🎨 Style)

- **You:** hats, trails, backs (wings, Arrow Quiver...) and auras. Every trail has a bright
  core ribbon from your waist to your feet, a soft outer glow, sparkles and a light; every aura
  adds a glowing halo on the ground.
- **In matches:** 🛏️ **Cloud Beds** (your team's bed uses the first teammate's pick),
  🗡️ **Sword Skins** (every sword you hold: colors, glowing edges, a light, particles and a
  streak through the air when you swing; 10 skins including Ruby, Thunder and Shadow),
  🏹 **Arrow Effects** (fletching color, a glowing flight streak and fire, frost, smoke or
  sparkles), and 💥 **Knockout Effects**
  (what bursts out when you knock someone out: lightning, fireworks, frost...), and
  💃 **Victory Dances**.

Most cost Sparks; a few cost Robux; each season's pass has 3 exclusive ones. Every cosmetic
you use adds its tier's **Style Bonus** to your match Sparks (up to +50%).

## Battle pass (🎟️ Pass)

A new season every 4 weeks (Autumn, Winter, Spring, Summer, forever). Earn ⭐ stars from matches
to climb 30 tiers. Free and Premium tracks give Sparks, random kits, shiny kits, 3 exclusive
kits and 3 exclusive cosmetics per season (a trail, a cloud bed and a knockout effect).
Premium, tier skips and the Star Booster pass (+50% stars) are sold for Robux.

## More

- 🎁 **Rewards:** 7-day login streak, 3 daily Bed Wars quests (knockouts, beds, wins, blocks,
  Crystals...), the Kit Collection, titles, codes and the daily prize wheel.
- **Titles** for wins, knockouts, final kills and beds broken; show one above your name.
- **Leaderboards** in the lobby for wins, knockouts and beds broken, with statues of the top 3.
- **Holiday events** (Halloween, Winter, Summer): every match earns the event currency, the
  lobby gets decorations, and the event shop sells exclusive kits.
- 👑 **Admin panel** (owner only): start or end a match, Admin Abuse (double Sparks), any
  weather, or Sparks for everyone. Admin Abuse also runs by itself once a week.
- 💎 **Robux shop:** VIP, Star Booster, Sparks, Golden Kit Crate, wheel spins, Battle Pass
  Premium, tier skips and Summon Rainbow Hour. Nothing sold makes you stronger in a match.

## Controls in a match

Click with a sword to swing (you can also hit placed blocks to break them), a pickaxe or axe
to mine blocks, the bow to shoot, a Fireball to throw it, a potion to drink it; hold a block or
Storm TNT to see where it goes and click to place it; **E** to open the Item Shop or break a
bed; **Shift** for your kit's power.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder
   to get Rojo, Selene and StyLua.
2. Install the Rojo plugin in Roblox Studio (`rojo plugin install`).
3. Run `rojo serve`, open a new Baseplate in Studio, and click **Connect** in the Rojo plugin.
   The game builds its own world and removes the Baseplate floor when it starts.
   (Or build a place file directly: `rojo build -o BottleAStorm.rbxl`.)
4. In **Game Settings**:
   - **Security → Enable Studio Access to API Services**, or saving is off.
     The server prints a warning when it is.
   - **Places → Max Players = 8.**

## Testing in Studio

- Press **Play**: a match starts after 15 seconds with just you. Use 👑 Admin → *Start match
  now* / *End match* to skip waiting, and the weather buttons to try each event.
- Use **Test → Clients and Servers** with 2+ players to fight and break beds.
- Robux items are free in Studio, so you can try every cosmetic and the battle pass premium.
- Set `Config.Holiday.StudioEvent` to try a holiday event.

## Before publishing

1. Create the passes and products on the Creator Dashboard, including one Developer
   Product per Robux cosmetic (`Products.Cosmetics`). Paste their IDs into
   `src/shared/Products.luau`. Items with ID 0 show "coming soon" in live servers.
2. Balance lives in `src/shared/Config.luau` (match timings, generators, combat, kit powers,
   weather) and `src/shared/MatchData.luau` (teams, shop, upgrades, match rewards).
3. Replace the part-built kits in `src/server/Modules/StormModel.luau` with real models
   when the art is ready. Nothing else needs to change.

## Code map

```
src/shared/   Config, MatchData (teams, modes, item shop, tools, upgrades, match rewards),
              MapData (map rotation), ProgressionData (levels, ranks, achievements), StormData (kits,
              rarities, powers), CosmeticsData, SkinData (swords, arrows), SeasonData
              (battle pass), RewardsData (daily rewards, quests), MarketData (Kit Shop,
              crates), SpinData, TitleData, HolidayData, WeatherEvents, Products, Sounds,
              Remotes, Format, Signal
src/server/   Main.server.luau starts the services in order
  Services/   DataService, MatchService (rounds, teams, beds, generators), CombatService,
              GadgetService (TNT, fireballs, potions, pickaxes, axes), PartyService,
              MapService, ProgressionService (levels, ranked, streaks, dances, achievements),
              BlockService, ItemShopService, KitService, WeatherService, MovementService
              (falling off), IncomeService (Sparks), IndexService (Kit Collection),
              SeasonService, RewardService, MarketService, SpinService, DailyService,
              TitleService, HolidayService, CosmeticService, ObbyService (lobby parkour),
              CommunityService (codes, group, likes), LeaderboardService, AdminService,
              MonetizationService
  Modules/    WorldBuilder (terrain islands, bridges, trees, forecast TV), ItemModels (weapons
              and items), StormModel (kit storms), Effects,
              Juice, Notify, Codes
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, MatchHUD (and the mode vote), CameraController, ItemShop, Kits, Party, KitController (Shift powers), KitFollower,
               WeaponController, BlockController, Aim, Shop, Market, HolidayShop, Style,
               Season, Rewards, AdminPanel, ForecastController, StormAnimator, FlashyFx,
               AmbientController, JuiceController, Toasts, Sfx, UI
```

## Known limits

- Kit powers and weapon aiming run on the player's own client (that's how Roblox moves
  characters), so an exploiter could fake a power. The server still checks every hit, block,
  purchase and bed break.
- All art is made from plain parts and emoji. Real 3D models and icons would be the next big
  visual step.

## Checks

```
selene src          # lint
stylua --check src  # formatting
rojo build -o BottleAStorm.rbxl
```
