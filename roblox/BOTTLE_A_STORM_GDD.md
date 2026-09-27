# Bottle a Storm ⛈️🫙 — Roblox Game Design Doc

> **One-liner:** Chase wild living storms across a floating sky world, trap them in jars, show them off on your Sky Island to earn money, and steal other players' rarest storms. Then team up when a Mega-Storm hits the whole server.

## 1. Why this should be popular (research basis, Sept 2026)

| What the charts show | What we take from it |
|---|---|
| *Grow a Garden* (21.6M concurrent) and *Steal a Brainrot* (25.4M concurrent) set all-time records with simple "collect → earn → protect/steal" loops | Same core loop: **collect storms → passive income → defend/steal** |
| *Steal an Egg* is #1 right now (~1.9M concurrent), with 8 rarity tiers and world events on a fixed schedule | Rarity ladder + **timed weather events** that make people log in at the same time |
| The fastest-growing genres are steal-and-defend tycoons, idle-grow sims, **co-op horror** (*99 Nights in the Forest*) and anime fighters | Adds a **co-op Mega-Storm survival phase** (the tension of 99 Nights) on top of the tycoon |
| Grow a Garden's mutation weather made "admin abuse" events go viral on TikTok and YouTube | Weather *is* the collectible, so every event is content |

**Is it new?** Storm games on Roblox today are realistic *chasing sims* (Twisted, Storm Inc., Tornado Blox, Storm Chaser Survival). I couldn't find any game that turns storms into **cute collectible creatures you bottle, display, and steal**. Dream-catching was also checked and is already taken (Sweet Dreams, Dreamland), so it was dropped.

## 2. Core loop (a 30-second pitch to a kid)

1. **Chase:** Storms (little cloud creatures with faces) roam the sky islands. Rarer ones move faster and dodge.
2. **Bottle:** Hold your jar up and win a short tug-of-war minigame. The rarer the storm, the harder it pulls.
3. **Display:** Put jars on pedestals on your **Sky Island**. Each storm makes **Sparks ⚡** (the currency) every second.
4. **Steal and defend:** Sneak onto other islands, grab a jar, and run it home. Owners defend with a lock timer, traps, and "zapping" thieves.
5. **Upgrade:** Spend Sparks on bigger jars, more pedestals, faster boots, and island defenses. Rebirth for multipliers.

## 3. Storm rarities (8 tiers, 60+ storms at launch)

| Tier | Examples | Sparks/sec |
|---|---|---|
| Common | Drizzle Dot, Puffcloud, Fog Bun | 1–5 |
| Uncommon | Hail Hopper, Breezy Boi, Mist Mouse | 10–25 |
| Rare | Thunder Pup, Snow Globe Sam, Dust Devil | 50–120 |
| Epic | Tornado Tony, Rainbow Squall, Sandstorm Sultan | 300–700 |
| Legendary | Hurricane Hana, Blizzard King, Monsoon Dragon | 2K–5K |
| Mythic | Aurora Serpent, Lava Rain Golem | 15K–40K |
| Cosmic | Meteor Shower Whale, Solar Flare Phoenix | 100K+ |
| Secret | Black Hole Baby, The Eye (a storm that stares back) | ??? |

**Mutations** (random on capture, stack with events): ⚡ Charged (x2), ❄️ Frozen (x3), 🔥 Molten (x4), 🌈 Prismatic (x6), 🌑 Void (x10), ✨ Golden (x15).
**Fusion:** put two storms in the Storm Mixer to make a hybrid. For example, Hail + Lava = "Obsidian Hail". Hybrid recipes are hidden, so the community has to find them (this drives wiki and TikTok traffic).

## 4. Special perks ⭐ (the hooks that make it different)

1. **Ride Your Storm:** Equip any bottled storm as a mount. Tornadoes spin you up to high islands, blizzards let you skate, lightning storms let you blink-dash. Every rarity is useful, not just a number.
2. **Server Weather Forecast:** A live TV in the lobby counts down to the next global event (Meteor Night, Rainbow Hour, Blood Moon Lightning). During events, rare storms spawn more often and mutations are boosted. This gives people a reason to log in on time.
3. **Mega-Storm Raid (co-op survival):** Every 45 minutes a giant boss storm (for example **Grandma Cyclone**) attacks the whole server. Players stop stealing, team up, and fire their bottled storms at it. If they fail, it rips a random pedestal off every island. If they win, everyone gets a guaranteed Epic+ egg-jar. It's the "99 Nights" tension in 3 minutes.
4. **Storm Personalities:** Each storm has a mood. Happy storms earn more, and bored storms try to escape their jar (the jar rattles and a mini "re-bottle" prompt appears). Players care about their collection instead of just counting it.
5. **Island Weather Aura:** Your island's sky takes on the look of your best storm (aurora skies, lava rain, snow). Other players can see your flex from across the map.
6. **Thief Kit Roles:** Pick a stealth style: *Lightning Rod* (fast grab), *Cloud Walker* (invisible for 5s), *Umbrella Tank* (can't be stunned). Light RPG choice without full combat balancing.
7. **Rebirth = "Climate Shift":** Resets Sparks but unlocks a new biome sky (Arctic, Volcano, Space) with new storms and a permanent x1.5 multiplier.

## 5. Things to buy 🛒

### Free (Sparks ⚡ from gameplay)
- Jars: Glass → Reinforced → Crystal → Quantum Jar (better catch strength)
- Pedestals (more storm slots), Island expansions
- Boots of Wind (speed), Cloud Hook (grappling), Lightning Rod traps, Laser Fence, Decoy Jars (look rare, explode into confetti when stolen 😂)
- Storm Food (keeps storms happy → +income)
- Cosmetic island themes, jar skins, trails

### Game Passes (Robux, bought once, owned forever)
| Pass | Price | What it does |
|---|---|---|
| VIP Storm Chaser | 199 R$ | +25% Sparks, gold nametag, VIP cloud lounge |
| Double Jar Capacity | 149 R$ | x2 pedestal slots |
| Auto-Collect | 99 R$ | Sparks go straight into your wallet, no walking to collect |
| Storm Radar | 249 R$ | Shows Legendary+ storms on your minimap |
| Fort Knox Lock | 179 R$ | Base lock lasts 2x longer |
| Lucky Jar | 299 R$ | +50% mutation chance |
| Storm Tamer | 399 R$ | Storms never escape, +1 fusion slot |

### Developer Products (Robux, can be bought again)
| Product | Price | What it does |
|---|---|---|
| Sparks bundles | 25 / 99 / 399 / 999 R$ | Currency packs |
| Instant Lock (5 min) | 19 R$ | Emergency base shield |
| Summon Weather Event | 79 R$ | Starts a server-wide Rainbow Hour. Everyone benefits, so the buyer gets hyped in chat (a social flex) |
| Mystery Storm Jar | 49 R$ | Random Rare–Mythic storm |
| Server Nuke: "Tornado Party" | 499 R$ | Spawns 10 Epic+ storms for the whole server (big YouTube/TikTok moment) |
| Mutation Reroll | 29 R$ | Reroll a storm's mutation |
| Skip Mega-Storm Loss | 39 R$ | Protect your pedestals during one raid |

### Also
- **Private servers:** 100 R$/month
- **Premium Payouts:** keep sessions long with the raid timer and the event forecast
- **Season Pass "Stormy Seasons":** free and premium tracks with exclusive storms, rotating every 4 weeks

## 6. Retention and LiveOps
- **Weekly update on Saturdays** (the Steal an Egg / Grow a Garden rhythm) with 1 new biome storm set + 1 limited event storm
- **Limited storms** (e.g. "Pumpkin Tornado" in October) → FOMO + trading
- **Trading hub** (trade-lock on newly bought storms to prevent scams)
- **Daily login jar**, streaks, group-join reward (+10% Sparks for joining the Roblox group)
- **Leaderboards:** Most Sparks, Most Steals, Rarest Collection

## 7. MVP scope (build order for Roblox Studio)
1. One sky biome, 15 storms (Common → Legendary), the bottle minigame
2. Sky Island plots with pedestals and passive Sparks
3. Stealing + base lock + basic traps
4. DataStore saving, 3 game passes, 2 dev products
5. Weather events + forecast TV
6. Mega-Storm raid (v1.1), fusion + riding (v1.2), trading (v1.3)

## Sources
- [Steal a Brainrot (Wikipedia)](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- [Grow a Garden (Wikipedia)](https://en.wikipedia.org/wiki/Grow_a_Garden)
- [Mi3: garden and brainrot games set new records](https://www.mi-3.com.au/17-12-2025/roblox-garden-brainrot-games-set-new-records-2025-unprecedented-player-engagement)
- [Steal An Egg codes (PCGamesN, Sept 2026)](https://www.pcgamesn.com/roblox/steal-an-egg-codes)
- [Steal an Egg: eggs, pets and income rates (GAMES.GG)](https://games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/)
- [Most popular Roblox game genres 2026 (KitsBlox)](https://kitsblox.com/blog/popular-roblox-game-genres-2026)
- [Roblox trends: genres and mechanics (Game-Ace)](https://game-ace.com/blog/roblox-trends-in-gaming/)
- [99 Nights in the Forest surpasses Grow a Garden](https://www.maxpowergaming.co/post/99-nights-in-the-forest-surpasses-grow-a-garden-roblox-s-september-breakout)
- [Roblox Game Pass pricing guide (2026)](https://generalistprogrammer.com/tutorials/roblox-game-pass-pricing-guide)
- [Roblox monetization guide (creation.dev)](https://www.creation.dev/blog/monetize-your-roblox-game)
- [Twisted (existing storm-chasing game)](https://www.roblox.com/games/6161235818/Twisted)
- [Sweet Dreams (existing dream game, why the dream idea was dropped)](https://www.roblox.com/games/130666358646922/Sweet-Dreams)
