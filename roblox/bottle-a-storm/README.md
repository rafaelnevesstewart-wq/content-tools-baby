# Bottle a Storm ⛈️🫙 (MVP)

The first playable version of the game in [`../BOTTLE_A_STORM_GDD.md`](../BOTTLE_A_STORM_GDD.md).
Everything is built from code, including the islands and the storm creatures, so it runs in Studio
with no uploaded art.

## What's in this build

These are steps 1–5 of the design doc's build order, plus the Mega-Storm raid (v1.1) and
storm mixing and riding (v1.2) and trading (v1.3). That completes the design doc's build plan.

| Feature | Where |
|---|---|
| Wild Skies island with 15 storms (Common → Legendary) that roam; Rare+ ones run from you | `StormSpawner`, `StormModel` |
| Catching by throwing your Storm Jar: rarer storms dodge and need 2–3 hits; 6 mutations | `CaptureService`, `ThrowController` |
| Storm Mixer: combine two storms; 11 secret hybrid recipes, including a new Mythic tier | `MixService`, `Recipes`, `Mixer` |
| Riding: pick a storm as your mount; speed boost plus a power based on its weather type | `RideService`, `RideController` |
| Trading storms and Sparks with other players, with anti-scam checks | `TradeService`, `Trade` |
| 8 player Sky Islands with pedestals, jar displays and a Collect pad for passive Sparks ⚡ | `PlotService`, `IncomeService` |
| Stealing: grab a jar, carry it home (70% speed); Zapper tool, Lightning Rod traps, 60 s base lock | `StealService`, `PlotService` |
| Sparks shop: jars, pedestals (3 → 10), Boots of Wind, Lightning Rod | `ShopService`, `Shop` |
| Saving with a session lock (no duplicate storms across servers), autosave, safe shutdown | `DataService` |
| 3 game passes (VIP, Double Pedestals, Auto-Collect) and 5 dev products (2 Sparks packs, Emergency Lock, Raid Shield, Summon Rainbow Hour) | `MonetizationService`, `Products` |
| Weather events every 10 min (Rainbow Hour, Thunder Frenzy, Meteor Night) + forecast TV | `WeatherService`, `ForecastController` |
| Mega-Storm raid every 45 min (details below) | `RaidService`, `RaidData`, `HUD` |

Not in this build yet: storm moods, island sky aura, thief styles, Climate Shift rebirth and the season pass.

## Controls

| Action | PC | Phone |
|---|---|---|
| Hold your Storm Jar | `1` (hotbar) | tap the jar |
| Throw the jar | click near a storm | tap near a storm |
| Zapper / Storm Launcher | `2` / `3`, then click | tap the tool, then tap |
| Pick a storm to ride | `R` on your pedestal | tap "Ride this storm" |
| Hop on / off | `Q` | Ride button |
| Use your ride's power | `Shift` | power button |
| Mix storms | `E` on your cauldron | tap "Mix Storms" |
| Trade | 🤝 Trade button | 🤝 Trade button |

## Catching: throw the jar

Hold the Storm Jar and click or tap on or near a storm. There's a little aim assist.
- **Too strong:** if your jar can't hold that rarity, it bounces off. Upgrade your jar in the Shop.
- **Dodge:** rarer storms may dodge (Uncommon 10%, Rare 25%, Epic 35%, Legendary 45%).
  Better jars cut that by up to 60%.
- **Hits:** each hit adds 💫 dizzy stars and freezes the storm for a moment. Commons and Uncommons
  need 1 hit, Rare and Epic 2, Legendary 3. A jar stronger than the storm saves one hit. Wait
  more than 6 seconds between hits and the stars wear off. If other players are throwing at the
  same storm, whoever finishes their hits first gets it.

## Storm Mixer

The cauldron on your island. Pick two of your storms, pay a Sparks fee (30 seconds of both
storms' income, minimum 50) and get one storm back on the first storm's pedestal.
- **Secret recipe:** you get a hybrid. There are 11, from Rare up to the new **Mythic** tier,
  which you can only get by mixing. The recipes live on the server only, so players have to
  discover and share them. New discoveries are announced to the server, and the mixer's recipe
  book lists the ones you've found. The full list is in `src/server/Modules/Recipes.luau`.
- **Any other pair:** a random wild storm of the higher rarity, with a 20% chance of one rarity up.
- The result keeps the better mutation of the two.

## Riding

Press `R` on one of your pedestals to make that storm your ride, then `Q` to hop on. The storm
floats under your feet and stays on its pedestal earning Sparks. You get +2 to +10 speed by
rarity, plus a power (`Shift`) based on its weather:

| Storms | Power |
|---|---|
| Wind (Breezy Boi, Tornado Tony, Hurricane Hana…) | 🌪️ **Updraft**: launches you high into the sky |
| Lightning (Thunder Pup, Thundernado…) | ⚡ **Blink Dash**: teleports you forward |
| Ice and sand (Hail Hopper, Dust Devil, Blizzard King…) | 🏄 **Surf Boost**: a burst of speed |
| Rain, fog and rainbow (Drizzle Dot, Fog Bun, Rainbow Squall…) | ☁️ **Cloud Jump**: jump again in mid-air, plus you glide |

You hop off automatically if you grab a stolen storm, or if your ride is sold, stolen or mixed.

## Trading

Press **🤝 Trade**, pick a player and send a request. They get an Accept/Decline pop-up, which
expires after 20 s.
- **Offers:** each side offers up to 4 storms and any amount of Sparks. Both players see both
  offers live.
- **Uneven warning:** the window shows how much income per second each side is worth, and warns
  you if you'd give more than 3x what you get.
- **Anti-scam:** any change un-readies **both** players. When both press Ready, a 5-second
  countdown runs, and any change stops it.
- **Final check:** before swapping, the server checks both players still own everything, have
  the Sparks, and have enough free pedestals. Storms that are being stolen can't be traded.
- **Swap:** everything moves at once, lands on free pedestals, and both players are saved
  right away. Leaving cancels the trade.

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
- [ ] Walk the bridge to the Wild Skies. Press **1** to hold the Storm Jar and click a storm.
      It gets sucked in and appears on a pedestal at home.
- [ ] Throw at a Rare storm with a Reinforced Jar: it may dodge, and needs 2 hits (💫 1/2).
- [ ] Sparks pile up on the yellow Collect pad. Step on it to collect.
- [ ] Press **R** on a pedestal, then **Q** to ride. Try **Shift** for the power.
- [ ] Press **E** on the purple cauldron. Mix Fog Bun + Mist Mouse to discover Ghost Fog.
      Mix two random commons to see an unknown mix.
- [ ] Trade (2 players): player 1 presses 🤝 Trade and picks player 2, and player 2 accepts.
      Add storms, press Ready on both and watch the countdown. Change something during the
      countdown and check it stops. Try trading with a full island.
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
              IncomeService, CaptureService, RideService, MixService, TradeService,
              StealService, RaidService, ShopService, MonetizationService
  Modules/    WorldBuilder (islands, bridges, TV), StormModel (creatures, jars),
              Recipes (secret mixer recipes), Notify
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, Shop, Mixer, Trade, ThrowController, RideController, Toasts,
               PromptController, ForecastController, UI
```

## Known limits

- Riding powers run on the player's own client (that's how Roblox moves characters), so an
  exploiter could fake them. That's normal for movement abilities; the server still checks
  every catch, steal and purchase.
- No offline earnings yet: storms only earn while you're in the game.
- All art is placeholder (plain parts, emoji in the UI).

## Checks

```
selene src          # lint
stylua --check src  # formatting
rojo build -o BottleAStorm.rbxl
```
