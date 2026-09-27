# Bottle a Storm ⛈️🫙 (MVP)

The first playable version of the game in [`../BOTTLE_A_STORM_GDD.md`](../BOTTLE_A_STORM_GDD.md).
Everything is built from code, including the islands and the storm creatures, so it runs in Studio
with no uploaded art.

## What's in this build

These are steps 1–5 of the design doc's build order, plus the Mega-Storm raid (v1.1) and
storm mixing and riding (v1.2) and trading (v1.3), plus every extra from the doc: storm moods,
the island sky aura, thief styles, the Climate Shift rebirth and the season pass. On top of that
there's a gameplay update (below): a free starter storm, catch combos, Golden Hunts, Storm Races,
guard storms, offline earnings, daily rewards, quests and the Storm Index. Update 2 adds storm
levels, storm buddies, storm battles, day and night, island themes, a big rare-catch moment,
titles and a round of balance changes.

| Feature | Where |
|---|---|
| Wild Skies island (330 studs across) with 15 storms (Common → Legendary) that roam; Rare+ ones run from you | `StormSpawner`, `StormModel` |
| Catching by throwing your Storm Jar: rarer storms dodge and need 2–3 hits; 6 mutations | `CaptureService`, `ThrowController` |
| Storm Mixer: combine two storms; 11 secret hybrid recipes, including a new Mythic tier | `MixService`, `Recipes`, `Mixer` |
| Riding: pick a storm as your mount; speed boost plus a power based on its weather type | `RideService`, `RideController` |
| Trading storms and Sparks with other players, with anti-scam checks | `TradeService`, `Trade` |
| Storm moods: happy storms earn more, neglected ones try to escape; pet, ride or feed them | `MoodService` |
| Island sky aura: a cloud canopy and weather over your island from your best storm | `AuraService` |
| Thief styles: Quick Hands, Cloud Walker or Umbrella Tank, unlocked with Sparks | `ThiefStyles`, `StealService`, `Shop` |
| Season pass "Stormy Seasons": 30 tiers of free and premium rewards, 4-week themed seasons with exclusive storms | `SeasonService`, `SeasonData`, `Season` |
| Climate Shift rebirth: reset Sparks for a permanent bonus and a new sky island (Arctic, Volcano, Space) with 12 exclusive storms and a Cosmic tier | `ClimateService`, `ClimateData`, `Climate`, `BiomeController` |
| 8 player Sky Islands with pedestals, jar displays and a Collect pad for passive Sparks ⚡ | `PlotService`, `IncomeService` |
| Stealing: grab a jar, carry it home (70% speed); Zapper tool, Lightning Rod traps, 90 s base lock, storm insurance | `StealService`, `PlotService` |
| Sparks shop: jars, pedestals (3 → 10), Boots of Wind, Lightning Rod, Storm Snacks, thief styles | `ShopService`, `Shop` |
| Saving with a session lock (no duplicate storms across servers), autosave, safe shutdown | `DataService` |
| 5 game passes (VIP, Double Pedestals, Auto-Collect, Storm Tamer, Cloud Flight) and 7 dev products (2 Sparks packs, Emergency Lock, Raid Shield, Season Premium, Skip a Season Tier, Summon Rainbow Hour) | `MonetizationService`, `Products` |
| Weather events every 5 min (Rainbow Hour, Thunder Frenzy, Meteor Night, Double Sparks Hour, Mutation Storm, Fog Night) + forecast TV | `WeatherService`, `ForecastController` |
| Mega-Storm raid every 25 min (details below) | `RaidService`, `RaidData`, `HUD` |

Everything in the design doc is now built.

## Look and feel (realistic)

- **Sky and light:**
  - Future lighting with soft shadows (set in `default.project.json`), haze, bloom, sun rays
    and gentle color grading.
  - Real 3D clouds in the sky (Terrain Clouds), and wispy smoke clouds under the islands
    (`WorldBuilder.setupLighting`).
- **Storms:** living little weather clouds.
  - Many overlapping puffs, lit on top and shadowed underneath, with soft wisps drifting off.
    They bob and drift slowly (`StormAnimator`).
  - Epic and rarer storms have a glowing core of their rarity's color.
  - Only Mega-Storm bosses and grumpy clouds have (glowing, angry) eyes.
  - Catching one spins it into the jar with a burst of confetti and a floating "+⚡/s" number.
- **Islands:** natural grass, earth and rock layers, wooden bridges, leafy trees in several
  greens, wildflowers, real-looking mushrooms and bushes (`WorldBuilder`).
- **Sky extras:** drifting mini islands, rainbows, flocks of birds and rising balloons. These
  are made on each player's screen only (`AmbientController`), so they cost the server nothing.
- **Menus:** a sleek dark theme with a clean font (Gotham) and bright accents.
  - There's one Sparks bar, small timer chips and an icon bar on the left that shrinks on
    phones.
  - Colors are in `UI.Colors` in `src/client/Controllers/UI.luau`.
- **Sounds and juice:**
  - Sounds: button clicks, jar throws, pops, coins, zaps and chimes (they also play with
    pop-up messages).
  - Collecting shows a floating "+⚡" number with sparkles.
  - Getting zapped, struck or trapped shakes the screen.
  - **Sound IDs** are in `src/shared/Sounds.luau`. They point at sounds built into the Roblox
    app. If one stays silent in Studio (the Output window says it failed to load), replace it
    with any Creator Store sound: Toolbox → Audio → right-click → Copy Asset ID, then paste
    it as `rbxassetid://…`.

## Gameplay update

Numbers for all of this are in `src/shared/Config.luau` (`Starter`, `Combo`, `Golden`, `Race`,
`Guard`, `Offline`, `Index`, `Quests`) and `src/shared/RewardsData.luau`.

- **Easier start:** new players get a free, happy Puffcloud on their island, so they earn from
  the first second. A sparkly arrow points to the nearest wild storm until the first catch
  (`RewardService`, `TutorialController`). Extra pedestals are cheaper (40 ⚡ to start).
- **Combo catches:** catch again within 10 seconds to build a combo (up to x10). Each step pays
  bonus Sparks and adds +2% mutation chance. A pink "COMBO x3!" pops up (`CaptureService`).
- **Golden Hunt** (every 4.5 min): a fast Golden Rare storm zooms around the Wild Skies for
  60 seconds. Any jar can catch it. The first to catch it wins 10 minutes of Sparks
  (min ⚡3,000) and keeps the Golden storm (`EventService`).
- **Storm Race** (every 6 min): rainbow rings appear around the Wild Skies with a 20 s
  countdown. Then a Prismatic storm races through them for 90 seconds. It never dodges but
  needs 3 hits. The winner gets 10 minutes of Sparks (min ⚡2,500) and keeps the storm.
- **Guard storms:** press `F` on a pedestal and pick **Guard**. That storm circles above your
  island and zaps thieves carrying your storms nearby. Rarer guards zap more often (every 12 s
  for Common down to 3 s for Cosmic). The storm still earns on its pedestal. If it's sold,
  traded, mixed or stolen, it stops guarding (`GuardService`).
- **Offline earnings:** storms keep earning at 25% while you're away (up to 8 hours). A
  "Welcome back!" pop-up shows how much when you return (`IncomeService`).
- **Daily rewards:** a 7-day login streak in 🎁 Rewards → Daily, ending in an Epic storm on
  day 7. Miss a day and it starts over. The window opens by itself when a reward is waiting
  (`DailyService`, `Rewards`).
- **Quests:** 3 small goals a day (catch, steal, mix, pet, collect, fight a Mega-Storm). Each
  one pays 5 minutes of Sparks and 150 ⭐ Season Stars.
- **Storm Index:** a collection book of every storm. The first time you get a new kind, it
  pays a bonus. Completing a whole rarity row gives **+5% Sparks forever** (`IndexService`).
- **More weather events:** Double Sparks Hour (everything earns x2), Mutation Storm (5x
  mutation chance) and Fog Night (rarer storms appear more often in the fog).
- **Mega-Storm raid every 25 minutes** (was 45), first one 10 minutes after a server starts.

## Update 2

**Gameplay**
- **Storm levels:** storms level up the longer you own them (time online): Lv 2 after
  5 minutes, up to Lv 10 after 28 hours. Each level adds +10% Sparks, so Lv 10 earns +90%.
  The level shows on the pedestal label, and a "LEVEL UP!" pops up. Levels stay with a
  storm when it's traded or stolen. A mixed storm starts again at Lv 1 (`StormData.LevelSeconds`,
  `IncomeService`).
- **Storm buddy:** press `F` on a pedestal and pick **Buddy**. That storm floats next to you
  everywhere so other players can see it, and keeps earning on its pedestal (`BuddyService`,
  `BuddyController`).
- **Storm battles:** press ⚔️ Battle and challenge a player. Your 3 strongest storms fight
  theirs, one at a time, in a battle window. Nobody loses a storm.
  - **Strength:** rarer, mutated and higher-level storms are stronger.
  - **Weather types:** Wind beats Rain, Rain beats Thunder, Thunder beats Ice and Ice beats
    Wind (x1.5 damage). There are also critical hits.
  - **Prizes:** the winner gets 2 minutes of Sparks (at least ⚡500) and the loser 30 seconds
    (at least ⚡100). Only the first 10 wins and 10 losses each day pay, so friends can't farm
    each other. There's a 90 s rest between battles (`BattleService`, `BattleData`, `Battle`).

**Look and feel**
- **Day and night:** a full day takes 12 minutes. Night is the last 30% and gets a soft blue
  light, and every storm glows in its own color. Weather events and the Mega-Storm still set
  their own sky (`WeatherService`, `StormAnimator`).
- **Island themes:** buy them in 🛒 Shop → 🏝️ Themes.
  - Candy Land ⚡5,000, Sunny Beach ⚡25,000, Snowy Peak ⚡100,000 and Starry Space ⚡500,000.
  - A theme recolors your island's ground, trees, bushes, flowers and mushrooms.
  - Switch back and forth for free once you own one (`ThemeService`, `ThemeData`).
- **Big rare-catch moment:** catching an Epic or better (or a Golden Hunt or race storm)
  flashes the screen, swoops the camera in on the storm, and shows a big "EPIC CATCH!" banner
  (`JuiceController`).
- **Titles:** 14 titles earned by playing: Storm Rookie, Thief King, Legend Hunter,
  Battle Champ and more.
  - Your first one shows above your name automatically.
  - Pick another in 🎁 Rewards → 🏷️ Titles (`TitleService`, `TitleData`).

**Balance**
- **Faster early game:**
  - New players earn **x2 Sparks for their first 15 minutes** of play, with a timer on the HUD.
  - Cheaper early upgrades: Reinforced Jar ⚡250, Crystal Jar ⚡10,000, first pedestal ⚡40,
    boots from ⚡100, first Lightning Rod ⚡500.
- **Stealing is less punishing:**
  - The free lock lasts 90 seconds (was 60).
  - **Storm insurance:** when a storm is stolen, you get 2 minutes of its income back.
- **Events more often:** weather every 5 minutes (was 10), Golden Hunt every 4.5 minutes and
  Storm Race every 6 minutes.
- **Rare storms are easier:**
  - Dodge chances are lower: Uncommon 5%, Rare 15%, Epic 22%, Legendary 30%.
  - Rare, Epic and Legendary storms spawn about 40–80% more often.

## Fighting: grumpy clouds and water balloons

- **Grumpy clouds** (`GrumpService`):
  - Up to 6 angry little clouds float around the Wild Skies and follow players.
  - Every few seconds one drops a raindrop where you're standing. Move and it misses. A hit
    pushes you and soaks you (slower for a moment).
  - Pop them with the **Cloud Blaster** (tool 3). Grumpy Clouds take 3 hits and big Storm
    Grumps take 10.
  - Everyone who hit one gets Sparks when it pops. A Storm Grump can also drop Storm Snacks
    or a Rare storm for the player who popped it.
  - Grumpy clouds hide during a Mega-Storm. There's a daily quest for them and a
    "Cloud Popper" title.
- **Water balloon fights** (`BalloonService`):
  - Throw **Water Balloons** (tool 4) at other players. Nobody gets hurt: a splash knocks them
    back and soaks them for 2 seconds.
  - **Thieves drop the storm** when splashed. An Umbrella Tank blocks the first one.
  - **Safe at home:** players standing on their own island can't be splashed.
  - Hitting players counts toward the "Splash Champ" title.
- Numbers are in `Config.Grumps`, `Config.Blaster` and `Config.Balloon`.

## Trending update

**Collecting**
- **🌊 Storm Parade** (`ParadeService`):
  - Storms float along a sky river across the Wild Skies, each with a price. Walk up and
    press `E` to buy one before it drifts away. First come, first served.
  - Rare ones are announced to the server.
  - Settings are in `Config.Parade`.
- **🫙 Mystery Jars** (🏪 Market → Mystery Jars, `MarketService`):
  - Cloud Jar ⚡1,000, Thunder Jar ⚡25,000 and Cosmic Jar ⚡750,000, each with its odds
    shown.
  - The Robux **Golden Jar** (99 R$) is always Epic or Legendary and always mutated.
  - The jar shakes, flashes and reveals your storm.
  - Odds are in `src/shared/MarketData.luau`.
- **🏪 Storm Market** (restocking):
  - 6 storms with limited stock, shared by everyone in the server. It restocks every
    5 minutes with a countdown.
  - Every server gets the same stock at the same time. A Legendary in stock is announced.
- **Stacking weather mutations** (`WeatherMutationService`):
  - During weather events, each storm on a pedestal has a 10% chance per minute to pick up
    a weather mutation: 💧 Wet x1.25, 🌫️ Misty x1.5, ☀️ Sunkissed x1.5, ⚡ Shocked x2,
    🌈 Rainbowed x2.5, 🌠 Starstruck x3 or 🌀 Chaotic x4.
  - Which ones depends on the event. They stack (up to 4) and multiply together.
  - They show on the pedestal label and count toward income, selling and trading.

**Social and growth**
- **🎟️ Redeem codes** (🎁 Rewards → Codes, `CommunityService`):
  - Codes live in `src/server/Modules/Codes.luau`, on the server only, so nobody can dig
    them out.
  - Each can be used once per player and can have an expiry date. Starter codes: `RELEASE`,
    `STORMY`, `THANKYOU`, `LIGHTNING`, `LIKES1K`.
- **👥 Group bonus:** group members get +10% Sparks. Put your group's ID in `Config.Group.Id`.
  Players can press "I joined! Check" in the Codes tab.
- **👍 Like goal:** a sign near the spawn and a line in the Codes tab (`Config.LikeGoal`).
  Roblox doesn't let games read their like count, so update the goal by hand and post a
  code when you reach it.
- **🏆 Global leaderboards** (`LeaderboardService`):
  - Three boards near the Wild Skies spawn show the world's top 10 for Sparks earned, storms
    caught and storms stolen. They update every 2 minutes (OrderedDataStores).
  - Avatar statues of the top 3 Sparks earners stand on a gold, silver and bronze podium.
  - Without data store access (Studio with API access off), the boards show this server's
    players.

**Events and fun**
- **🎡 Daily spin wheel** (🎁 Rewards → Spin, `SpinService`):
  - One free spin a day; the Robux "3 Wheel Spins" product (49 R$) gives more.
  - 10 prizes, from 10 minutes of Sparks up to a Legendary storm. Odds are in
    `src/shared/SpinData.luau`.
  - The prize is announced when the wheel stops.
- **👑 Admin Abuse** (`AdminService`, `AdminPanel`):
  - The game's owner (plus anyone in `Config.Admin.UserIds`, and everyone in Studio) gets a
    👑 Admin button.
  - From it you can start ADMIN ABUSE (30 minutes of x2 Sparks, x10 luck and a storm rain
    every minute), 10x luck, a storm rain, a Mega-Storm right now, a Golden Hunt, a Storm Race,
    any weather, or give everyone Sparks.
  - Admin Abuse also starts by itself every Saturday at 17:00 UTC (`Config.Admin`). A HUD
    chip counts it down.
- **🎉 Holiday events** (`HolidayService`, `HolidayData`):
  - Spooky Skies 🎃 (Oct 15–Nov 5), Frosty Skies 🎄 (Dec 10–Jan 6) and Sunny Skies 🏖️
    (Jun 20–Jul 20).
  - While one is on, its Epic and Legendary storms roam the Wild Skies. Every catch earns the
    event currency (🍬 Candy, ❄️ Snowflakes, 🐚 Seashells).
  - The Wild Skies gets glowing pumpkins, snowmen or beach umbrellas. The 🏪 Market gets an
    🎉 Event tab that sells the event storms and extras.
  - **In Studio, Halloween is always on so you can test it** (`Config.Holiday.StudioEvent`;
    set it to `nil` to use the real calendar).
- **🏔️ Secret sky obby** (`ObbyService`):
  - A hidden path of 30 cloud platforms starts behind the trees at the edge of the Wild Skies
    (southwest, about 200° around) and climbs to a secret island.
  - Touch both glowing checkpoints on the way, then claim a free Legendary storm at the
    shrine, once a day (and earn the "Sky Climber" title).
  - Cloud Flight switches off near the path, so you have to climb it.

## Cosmetics (🎨 Style)

Bought in the 🎨 Style window, mostly with Sparks. A few special ones are Robux Developer
Products (`Products.Cosmetics`). Buying something puts it on right away. Tap it again later
to swap. Everything is built from parts on the server, so everyone sees it
(`CosmeticService`, `CosmeticsData`, `Style`).

| For | What | Sparks | Robux |
|---|---|---|---|
| You | 🎩 **Hats**: Rain Cloud Hat (drizzles), Lightning Crown, Rainbow Cap, Snowflake Beanie, Tornado Top Hat | ⚡2K–400K | 👑 Golden Storm Crown 49 R$ |
| You | ✨ **Trails** (a bright core, a soft glow and particles like flames, petals or stars): Rainbow, Sparkle, Snowflake, Fire, Cherry Blossom, Tornado, Aurora, Shadow, Lightning, Plasma, Bubble, Starfall | ⚡5K–1M | 🌌 Galaxy 49 R$, ⛈️ Thunderstorm 49 R$, 🐦‍🔥 Phoenix 79 R$ |
| You | ☁️ **Flight clouds** (skins for Cloud Flight): Cumulus (free), Storm (drizzles), Sunset, Snow, Rainbow, Golden | ⚡5K–400K | ⚡ Thunder Cloud 49 R$ (flashes with lightning), 🌌 Aurora Cloud 79 R$ |
| You | 🪽 **Backs**: Storm Jar Backpack, Cloud Wings, Butterfly Wings, Mini Tornado | ⚡3K–500K | 🌈 Rainbow Wings 79 R$ |
| You | 💫 **Auras**: Sparkle, Rain Halo, Lightning Orbit | ⚡8K–300K | 💕 Love Aura 39 R$ |
| Island | 🏛️ **Pedestal styles**: Marble (free), Candy, Gold, Cloud, Crystal | ⚡10K–150K | 🌈 Rainbow Pedestals 49 R$ |
| Island | ⛲ **Decorations** (use as many as you like): Lamp Posts, Fountain, Rainbow Arch, Golden Storm Statue (of your best storm), Fireworks (at night) | ⚡5K–500K | |
| Island | 🚩 **Sign and flag**: sign color and emoji (free); flags: Storm, Lightning, Rainbow, Sky Pirate | ⚡2K–80K | ✨ Golden Flag 29 R$ |
| Island | 🐤 **Island pets** (up to 3 kinds, 2 of each; real animals with legs and feather, fur, wool or scale textures): Mallard Ducks, Rabbits (they hop), Sheep | ⚡10K–90K | 🐉 Baby Storm Dragon 79 R$ (flies) |

## Cloud Flight (game pass, 199 R$)

Press `G` (☁️ Fly on phones) to hop on a fluffy cloud and fly anywhere for 30 seconds. Move as
normal; `Space` goes up and `Ctrl` or `C` goes down. After landing, the cloud rests for
20 seconds. Everyone sees your cloud.
- **Grabbing a stolen storm lands you right away**, so thieves still have to run and can be
  zapped. Getting zapped or stunned also knocks you off the cloud.
- **Players without the pass** who press `G` are offered the pass.
- Numbers are in `Config.Flight`. Like riding powers, flying runs on the player's own screen.

## Controls

| Action | PC | Phone |
|---|---|---|
| Hold your Storm Jar | `1` (hotbar) | tap the jar |
| Throw the jar | click near a storm | tap near a storm |
| Zapper, Cloud Blaster, Water Balloons | `2`, `3`, `4`, then click | tap the tool, then tap |
| Storm Launcher (during a Mega-Storm) | `5`, then click | tap the tool, then tap |
| Pet your storm (or calm an escaping one) | `E` on your pedestal | tap "Pet" |
| Options menu: Ride, Guard, Buddy or Sell a storm | `F` on your pedestal | tap "Options" |
| Hop on / off | `Q` | Ride button |
| Use your ride's power | `Shift` | power button |
| Mix storms | `E` on your cauldron | tap "Mix Storms" |
| Trade | 🤝 Trade button | 🤝 Trade button |
| Daily reward, quests, Storm Index, titles | 🎁 Rewards button | 🎁 Rewards button |
| Storm battle | ⚔️ Battle button | ⚔️ Battle button |
| Fly on a cloud (Cloud Flight pass) | `G`, then `Space` up / `Ctrl` or `C` down | ☁️ Fly, then ⬆️ / ⬇️ |
| Island themes | 🛒 Shop → 🏝️ Themes | 🛒 Shop → 🏝️ Themes |
| Cosmetics (character and island) | 🎨 Style button | 🎨 Style button |

## Catching: throw the jar

Hold the Storm Jar and click or tap on or near a storm. There's a little aim assist.
- **Too strong:** if your jar can't hold that rarity, it bounces off. Upgrade your jar in the Shop.
- **Dodge:** rarer storms may dodge (Uncommon 5%, Rare 15%, Epic 22%, Legendary 30%).
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

Press `F` on one of your pedestals and pick **Ride** to make that storm your ride, then `Q` to hop on. The storm
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

## Season pass: "Stormy Seasons"

Press **🎟️ Season**. The button shows how many rewards are waiting, like "(2!)".

- **Seasons:** each lasts **4 weeks** and they rotate forever. Each theme has 3 exclusive storms
  you can only get from its pass. They never appear in the wild, so they're great for trading.

  | Order | Theme | Free (tier 20) | Premium (tier 10) | Premium (tier 30) |
  |---|---|---|---|---|
  | 1 (now, from 21 Sep 2026) | 🍂 Autumn Gusts | Leafy Breeze (Epic) | Pumpkin Tornado (Legendary) | Harvest Moon Squall (Mythic) |
  | 2 | 🎄 Winter Wonder | Jingle Flurry | Candy Cane Cyclone | Aurora Reindeer |
  | 3 | 🌸 Spring Showers | Blossom Drizzle | Petal Twister | Cherry Monsoon |
  | 4 | ☀️ Summer Heatwave | Sunny Puff | Heatwave Hawk | Tropical Typhoon |

- **Season Stars ⭐:** 250 per tier, 30 tiers (7,500 total, about 7–8 hours of play). You earn
  them from:
  - 3 a minute online
  - 8 × rarity per catch
  - 30 per steal
  - 20 per mix
  - 60 for fighting a raid, +100 if the server wins
- **Rewards:** every tier has a free reward (top row) and a premium reward (bottom row). They
  include Sparks (scaled to your income), Storm Snacks, Raid Shields, random storms (some
  mutated) and the exclusives. Tap a glowing reward to claim it. Storm rewards need a free
  pedestal; if your island is full, the claim is refused and the reward waits.
- **Season Premium (299 R$):** unlocks the premium row for the current season, including tiers
  you've already passed. Buying it twice gives 3 tier skips instead.
  **Skip a Tier (49 R$)** gives 250 stars.
- **New seasons:** stars, claims and Premium reset. Unclaimed rewards from the old season are lost.
- **Editing:** tiers and rewards are in `src/shared/SeasonData.luau` (one line per tier), and
  star amounts are in `Config.Season`. Themes rotate every 4 weeks no matter the real-world
  season. Add a holiday theme by adding it to `Themes`, with its 3 storms in `StormData`.

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
- **Flying doesn't keep you safe:** the boss targets players flying over the Wild Skies too. Their
  red circle appears in the air at their height, and a hit knocks them off their cloud.
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
- [ ] New player: a Puffcloud is already on your island and an arrow points to the Wild Skies.
      Catch two storms quickly to see "COMBO x2!".
- [ ] Press **F** on a pedestal and pick **Ride**, then **Q** to ride. Try **Shift** for the power.
- [ ] Press **F** and pick **Guard**: the storm circles your island. With player 2, steal a storm
      and run under it. You get zapped. Pick **Sell** and tap it twice to sell.
- [ ] 🎁 Rewards: claim the Day 1 reward, check the quests fill up as you play, and look at the
      Storm Index. Catch a new kind of storm to see the Index bonus.
- [ ] Golden Hunt starts 30 s after you press Play in Studio, and a Storm Race after 75 s.
      Catch them to see the prize.
- [ ] Update 2: check the 🚀 Beginner Boost timer on the HUD. Wait 5 minutes and a storm
      reaches Lv 2. Press **F** → **Buddy** and walk around. Buy a theme in 🛒 Shop →
      🏝️ Themes. Within 12 minutes the sky goes dark for a while, and the storms glow.
      With 2 players, press ⚔️ Battle to fight. Open 🎁 Rewards → 🏷️ Titles after your first
      catch. To see the rare-catch moment quickly, set `Config.Jars[1].maxRarity = 5` and
      catch an Epic.
- [ ] Cosmetics: press 🎨 Style. Robux items are free in Studio. Put on a hat, trail, back and
      aura. Place every decoration and pet, change the sign color and emoji, and pick a flag.
      Check they show on your island.
- [ ] Fighting: on the Wild Skies, press **3** and click a grumpy cloud until it pops. Stand
      still under one to get splashed. With 2 players, press **4** and throw a balloon at
      player 2 (off their island, then on it), and at a thief carrying a storm.
- [ ] Trending update: buy a storm from the Storm Parade (E). In 🏪 Market, buy from the
      Storm Market and open a Mystery Jar. Use the 👑 Admin panel to start a weather event and
      wait for weather mutations, or start Admin Abuse. Try a code (`RELEASE`), spin the wheel,
      check the leaderboards near the spawn, visit the 🎉 Event tab (Halloween in Studio), and
      climb the secret sky path.
- [ ] Cloud Flight: press **G**. In Studio it grants the pass for free. Press **G** again to
      fly, try Space and Ctrl, then steal a storm while flying (you should land).
- [ ] Offline earnings: play, leave, and join again after 2+ minutes. (In Studio, turn on
      Game Settings → Security → Enable Studio Access to API Services so data saves.)
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
- [ ] Season pass: open 🎟️ Season and claim tier rewards as you earn stars. In Studio, the
      "Skip a tier" and "Unlock Premium" buttons are free, so skip to tier 10 and claim the
      Pumpkin Tornado.
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

1. Create the passes and products on the Creator Dashboard, including one Developer
   Product per Robux cosmetic (`Products.Cosmetics`). Paste their IDs into
   `src/shared/Products.luau`. Items with ID 0 show "coming soon" in live servers.
2. Balance lives in `src/shared/Config.luau` (prices, speeds, lock times, event timers).
3. Replace the part-built storms in `src/server/Modules/StormModel.luau` with real models
   when the art is ready. Nothing else needs to change.

## Code map

```
src/shared/   Config, StormData (storms, rarities, mutations, moods), Economy (prices),
              Products (Robux IDs), WeatherEvents, RaidData (bosses), ThiefStyles, ClimateData,
              SeasonData, RewardsData (daily rewards, quests), BattleData, TitleData,
              ThemeData, CosmeticsData, MarketData, SpinData, HolidayData, Sounds,
              Remotes, Format, Signal
src/server/   Main.server.luau starts the services in order
  Services/   DataService, PlotService, StormSpawner, WeatherService, MovementService,
              IncomeService, CaptureService, RideService, MoodService, SeasonService, MixService,
              TradeService, StealService, GuardService, BuddyService, FlightService, GrumpService,
              BalloonService, WeatherMutationService, ParadeService, MarketService,
              CommunityService, LeaderboardService, SpinService, AdminService,
              HolidayService, ObbyService, RaidService,
              IndexService, RewardService, DailyService, EventService, BattleService,
              TitleService, AuraService, ClimateService, ThemeService,
              CosmeticService, ShopService,
              MonetizationService
  Modules/    WorldBuilder (islands, bridges, TV), StormModel (creatures, jars), Codes,
              Recipes (secret mixer recipes), Notify
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, Shop, Mixer, Trade, Climate, Season, Rewards, PedestalMenu, Battle,
               BuddyController, FlightController, CombatController, Aim, Style, Market,
               HolidayShop, AdminPanel,
               BiomeController, ThrowController, RideController, Toasts, TutorialController,
               StormAnimator, AmbientController, JuiceController, Sfx,
               PromptController, ForecastController, UI
```

## Known limits

- Riding powers run on the player's own client (that's how Roblox moves characters), so an
  exploiter could fake them. That's normal for movement abilities; the server still checks
  every catch, steal and purchase.
- All art is still made from plain parts and emoji (now much cuter). Real 3D models and
  icons would be the next big visual step.

## Checks

```
selene src          # lint
stylua --check src  # formatting
rojo build -o BottleAStorm.rbxl
```
