# Bottle a Storm ⛈️🫙 (MVP)

The first playable version of the game in [`../BOTTLE_A_STORM_GDD.md`](../BOTTLE_A_STORM_GDD.md).
Everything is built from code, including the islands and the storm creatures, so it runs in Studio
with no uploaded art.

## What's in this build

These are steps 1–5 of the design doc's build order, plus the Mega-Storm raid (v1.1).

| Feature | Where |
|---|---|
| Wild Skies island with 15 storms (Common → Legendary) that roam; Rare+ ones run from you | `StormSpawner`, `StormModel` |
| Bottling tug-of-war minigame, jar tier limits which rarities you can catch, 6 mutations | `CaptureService`, `CaptureMinigame` |
| 8 player Sky Islands with pedestals, jar displays and a Collect pad for passive Sparks ⚡ | `PlotService`, `IncomeService` |
| Stealing: grab a jar, carry it home (70% speed); Zapper tool, Lightning Rod traps, 60 s base lock | `StealService`, `PlotService` |
| Sparks shop: jars, pedestals (3 → 10), Boots of Wind, Lightning Rod | `ShopService`, `Shop` |
| Saving with a session lock (no duplicate storms across servers), autosave, safe shutdown | `DataService` |
| 3 game passes (VIP, Double Pedestals, Auto-Collect) and 5 dev products (2 Sparks packs, Emergency Lock, Raid Shield, Summon Rainbow Hour) | `MonetizationService`, `Products` |
| Weather events every 10 min (Rainbow Hour, Thunder Frenzy, Meteor Night) + forecast TV | `WeatherService`, `ForecastController` |
| Mega-Storm raid every 45 min (details below) | `RaidService`, `RaidData`, `HUD` |

Not in this build yet: fusion and riding storms (v1.2), trading (v1.3),
storm moods, island sky aura, thief styles, Climate Shift rebirth and the season pass.

## The Mega-Storm raid

- **Warning:** 60 seconds before, the sky darkens and everyone is told to go to the Wild Skies.
  The HUD and forecast TV count down.
- **Fight (3 minutes):** a boss drops out of the sky. There are 3 bosses: Grandma Cyclone,
  The Thunder Titan and Sir Blizzardington. Everyone gets a **Storm Launcher** that aims itself.
  Click to fire. You must be on the Wild Skies island to hit the boss.
  - Damage per shot grows with your income: x1 with nothing, about x6 at 100K ⚡/s.
  - Boss HP adds up the same multiplier for every player in the server. A server where about 60%
    of players fight should win.
- **Boss attacks:** lightning strikes on red circles (1.5 s stun, so move!) and every third
  attack a gust that blows everyone outward. Stand near the edge and you might fly off.
  Below 30% HP it attacks faster.
- **During the raid:** stealing is off, carried storms fly home, and wild storms hide.
- **Win:** everyone who dealt damage gets an Epic storm (15% Legendary; the top damage dealer
  gets 30%), placed on their island. If the island is full, it's paid out as 10 minutes of that
  storm's income instead.
- **Lose:** every island loses one random storm. Players who joined in the last 10 minutes are
  safe, and a **Raid Shield** (39 R$ dev product) protects you once.

Timing and balance are in `Config.Raid`. In Studio the first raid comes after 45 seconds, then
every 5 minutes.

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
   - **Places → Max Players = 8.** There is one island per player. A 9th player is kicked
     with a "server full" message.

## Testing in Studio

Use **Test → Clients and Servers** with 2 players to try stealing.

- [ ] You spawn on your island. The sign says "<name>'s Island".
- [ ] Walk the bridge to the Wild Skies. Press **E** on a storm and hold click/tap/Space to keep
      the 🫙 under the ⛈️ until the meter fills. The storm appears on a pedestal at home.
- [ ] Sparks pile up on the yellow Collect pad. Step on it to collect.
- [ ] Buy a Reinforced Jar in the Shop, then catch a Rare storm.
- [ ] With player 2, hold **E** on player 1's pedestal. Player 1 gets a warning. Player 1
      equips the Zapper and clicks near player 2, and the storm flies back.
- [ ] Press the blue Lock button. Player 2 is pushed out and can't steal until it ends.
- [ ] Robux tab: with IDs still at 0, Studio grants items for free so you can test them.
- [ ] To test weather, set `Config.Weather.FirstEventDelay` to 10.
- [ ] Raid: wait 45 s after starting. Walk to the Wild Skies, click to fire, dodge the red
      circles. Try both winning and letting the timer run out. To lose easily, set
      `Config.Raid.HpPerPlayer` very high; set `NewPlayerGraceSeconds` to 0 to see a storm get
      blown away.

## Before publishing

1. Create the passes and products on the Creator Dashboard. Paste their IDs into
   `src/shared/Products.luau`. Items with ID 0 show "coming soon" in live servers.
2. Balance lives in `src/shared/Config.luau` (prices, speeds, lock times, event timers).
3. Replace the part-built storms in `src/server/Modules/StormModel.luau` with real models
   when the art is ready. Nothing else needs to change.

## Code map

```
src/shared/   Config, StormData (rarities, 15 storms, mutations), Economy (prices),
              Products (Robux IDs), WeatherEvents, RaidData (bosses), Remotes, Format, Signal
src/server/   Main.server.luau starts the services in order
  Services/   DataService, PlotService, StormSpawner, WeatherService, MovementService,
              IncomeService, CaptureService, StealService, RaidService, ShopService,
              MonetizationService
  Modules/    WorldBuilder (islands, bridges, TV), StormModel (creatures, jars), Notify
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, Shop, CaptureMinigame, Toasts, PromptController, ForecastController, UI
```

## Known limits

- The client runs the minigame and reports a win. The server rejects wins that come too fast
  (< 1.8 s) or from too far away (> 30 studs), but a cheater could still auto-win catches.
  Harden this before a big launch, for example with server-side replay of input timing.
- No offline earnings yet: storms only earn while you're in the game.
- All art is placeholder (plain parts, emoji in the UI).

## Checks

```
selene src          # lint
stylua --check src  # formatting
rojo build -o BottleAStorm.rbxl
```
