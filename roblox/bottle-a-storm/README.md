# Bottle a Storm ⛈️🫙 (MVP)

The first playable version of the game in [`../BOTTLE_A_STORM_GDD.md`](../BOTTLE_A_STORM_GDD.md).
Everything is built from code, including the islands and the storm creatures, so it runs in Studio
with no uploaded art.

## What's in this build

These are steps 1–5 of the design doc's build order, plus the Mega-Storm raid (v1.1) and
storm mixing and riding (v1.2) and trading (v1.3), plus four extras from the doc: storm moods,
the island sky aura, thief styles and the Climate Shift rebirth.

| Feature | Where |
|---|---|
| Wild Skies island with 15 storms (Common → Legendary) that roam; Rare+ ones run from you | `StormSpawner`, `StormModel` |
| Catching by throwing your Storm Jar: rarer storms dodge and need 2–3 hits; 6 mutations | `CaptureService`, `ThrowController` |
| Storm Mixer: combine two storms; 11 secret hybrid recipes, including a new Mythic tier | `MixService`, `Recipes`, `Mixer` |
| Riding: pick a storm as your mount; speed boost plus a power based on its weather type | `RideService`, `RideController` |
| Trading storms and Sparks with other players, with anti-scam checks | `TradeService`, `Trade` |
| Storm moods: happy storms earn more, neglected ones try to escape; pet, ride or feed them | `MoodService` |
| Island sky aura: a cloud canopy and weather over your island from your best storm | `AuraService` |
| Thief styles: Quick Hands, Cloud Walker or Umbrella Tank, unlocked with Sparks | `ThiefStyles`, `StealService`, `Shop` |
| Climate Shift rebirth: reset Sparks for a permanent bonus and a new sky island (Arctic, Volcano, Space) with 12 exclusive storms and a Cosmic tier | `ClimateService`, `ClimateData`, `Climate`, `BiomeController` |
| 8 player Sky Islands with pedestals, jar displays and a Collect pad for passive Sparks ⚡ | `PlotService`, `IncomeService` |
| Stealing: grab a jar, carry it home (70% speed); Zapper tool, Lightning Rod traps, 60 s base lock | `StealService`, `PlotService` |
| Sparks shop: jars, pedestals (3 → 10), Boots of Wind, Lightning Rod, Storm Snacks, thief styles | `ShopService`, `Shop` |
| Saving with a session lock (no duplicate storms across servers), autosave, safe shutdown | `DataService` |
| 4 game passes (VIP, Double Pedestals, Auto-Collect, Storm Tamer) and 5 dev products (2 Sparks packs, Emergency Lock, Raid Shield, Summon Rainbow Hour) | `MonetizationService`, `Products` |
| Weather events every 10 min (Rainbow Hour, Thunder Frenzy, Meteor Night) + forecast TV | `WeatherService`, `ForecastController` |
| Mega-Storm raid every 45 min (details below) | `RaidService`, `RaidData`, `HUD` |

Not in this build yet: the season pass.

## Controls

| Action | PC | Phone |
|---|---|---|
| Hold your Storm Jar | `1` (hotbar) | tap the jar |
| Throw the jar | click near a storm | tap near a storm |
| Zapper / Storm Launcher | `2` / `3`, then click | tap the tool, then tap |
| Pet your storm (or calm an escaping one) | `E` on your pedestal | tap "Pet" |
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

## Storm moods

Every storm has a mood, shown on its pedestal label:

| Mood | Earns |
|---|---|
| 😄 Happy (70+) | ×1.25 |
| 🙂 Content (40+) | ×1 |
| 😐 Bored (15+) | ×0.8 |
| 😤 Restless (under 15) | ×0.5, and it may try to escape |

- **Losing mood:** new storms start at 80. Moods drop 2.5 points a minute, **only while you're
  online**. That's Bored after about 16 minutes and Restless after about 26.
- **Cheering up:**
  - **Pet it:** `E` on your own pedestal, +25, once every 45 s per storm.
  - **Ride it:** +20 a minute while riding.
  - **🍪 Storm Snacks:** from the Shop, makes every storm fully Happy. It costs 60 seconds of
    your storms' base income, minimum ⚡100.
- **Escapes:** a Restless storm has a 25% chance per minute to try to escape. Its jar shakes, a
  warning appears and you get a toast. You have 30 s to press `E` on it. If you don't, it's
  gone. Wild kinds fly back to the Wild Skies, where anyone can catch them again.
- **Storm Tamer pass (399 R$):** storms never escape, and moods drop half as fast.
- **Trades and steals:** a storm keeps its mood when it's traded or stolen.

## Island sky aura

A ring of clouds floats above every island, tinted in the colours of that island's best storm
(by income). That storm's weather falls over the island: rain, snow, hail, fog, wind swirls,
lightning sparks with flashes, sand or rainbow sparkles.
- **Strength:** rarer storms make a stronger aura.
- **Mutations:** mutated storms add sparkles.
- **Legendary and Mythic:** these shine a beam of light into the sky that's visible from
  anywhere on the map.
- **Label:** "✨ Legendary Sky: Hurricane Hana", readable from far away.
- **Updates:** within about 2 seconds of your best storm changing.

## Climate Shift (rebirth)

Press **🌍 Climate** to see your climate and what the next shift needs.

| Climate | Needs | Income bonus (permanent) | Island storms |
|---|---|---|---|
| 🌤️ Temperate | start | x1 | the Wild Skies |
| ❄️ Arctic | ⚡5M | x1.5 | Frostbite Pup (Rare), Snowball Yeti (Epic), Glacier Guardian (Legendary), Polar Aurora (Mythic) |
| 🌋 Volcano | ⚡100M | x2.25 | Ember Puff (Rare), Magma Moth (Epic), Ash Storm Drake (Legendary), Lava Rain Golem (Mythic) |
| 🌌 Space | ⚡2B | x3.375 | Stardust Sprite (Epic), Comet Kid (Legendary), Meteor Shower Whale and Solar Flare Phoenix (new **Cosmic** tier) |

- **Resets:** Sparks, Boots of Wind and Lightning Rod.
- **Keeps:** storms, pedestals, jars, thief styles and passes.
- **Confirming:** the button has to be pressed twice.
- **Getting there:** each climate's island floats far out in the sky. Reach it through its portal
  in the row on the Wild Skies (past the forecast TV); locked portals tell you what you need.
  A portal on each island takes you back. Portals won't take stolen storms.
- **Catching:** only players who reached that climate can catch its storms (the jar bounces off
  otherwise). Anyone can own them through trading or stealing.
- **New jars:** Mythics need the **Aurora Jar** (⚡2M, Arctic+), and Cosmics need the **Cosmic Jar**
  (⚡500M, Space).
- **How each island feels:** a colour tint on your screen, and **low gravity in Space**.
- **Tuning:** climate numbers are in `src/shared/ClimateData.luau`; biome storms are in
  `StormData`.

## Thief styles

In the Shop's **🥷 Styles** tab, unlock a style with Sparks once, then equip one at a time. You
can switch between the ones you own for free, but not while carrying a stolen storm.

| Style | Cost | What it does |
|---|---|---|
| ⚡ Quick Hands | ⚡1,000 | Grab jars in 0.5 s instead of 1.5 s |
| ☁️ Cloud Walker | ⚡5,000 | Almost invisible (90%) with no name tag for 5 s after grabbing a jar |
| ☂️ Umbrella Tank | ⚡15,000 | Lightning Rod traps can't stun you; your umbrella blocks the first zap and zaps never stun you. You carry at 60% speed instead of 70% |

The design doc calls the first style "Lightning Rod". It's renamed Quick Hands so it isn't
confused with the Lightning Rod trap. The numbers are in `src/shared/ThiefStyles.luau`.

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
- [ ] Moods: check the 😄 label on a new storm and press **E** on it to pet it. Buy Storm Snacks.
      To see an escape quickly, set `Config.Mood.DecayPerMinute` to 60 and
      `EscapeChancePerMinute` to 1. Let a storm hit 😤, watch its jar shake, then calm it with E
      (or let it escape).
- [ ] Sky aura: catch a storm and look up. Its clouds and weather appear over your island.
      A Legendary adds a light beam.
- [ ] Thief styles (2 players): player 2 buys each style in 🥷 Styles and steals from player 1.
      Quick Hands grabs faster. Cloud Walker turns see-through. Umbrella Tank ignores player 1's
      Lightning Rod trap and survives the first zap.
- [ ] Climate Shift: in Studio, test cheaply by lowering `cost` in `ClimateData` (for example 1000).
      Shift, check Sparks reset and the income bonus, walk through the ❄️ portal, catch an
      Arctic storm, feel the tint. For Space, check the low gravity. The portal back takes you
      home.
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
src/shared/   Config, StormData (storms, rarities, mutations, moods), Economy (prices),
              Products (Robux IDs), WeatherEvents, RaidData (bosses), ThiefStyles, ClimateData,
              Remotes, Format, Signal
src/server/   Main.server.luau starts the services in order
  Services/   DataService, PlotService, StormSpawner, WeatherService, MovementService,
              IncomeService, CaptureService, RideService, MoodService, MixService,
              TradeService, StealService, RaidService, AuraService, ClimateService,
              ShopService, MonetizationService
  Modules/    WorldBuilder (islands, bridges, TV), StormModel (creatures, jars),
              Recipes (secret mixer recipes), Notify
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, Shop, Mixer, Trade, Climate, BiomeController, ThrowController,
               RideController, Toasts,
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
