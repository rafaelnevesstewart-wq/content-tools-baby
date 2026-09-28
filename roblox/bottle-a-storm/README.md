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

Everyone waits in the **castle lobby**, a stone castle on its own floating island (walls,
towers, torches, a fountain, the forecast TV, leaderboards and winners' statues). With 2+
players (1 in Studio) a 15-second countdown starts. In the lobby, players **vote for Solos,
Duos, Squads or 🍀 Lucky Blocks** (team size 1, 2, 4, or duos with ❓ blocks all over the map
that give a surprise after 3 sword hits: gear, TNT, resources... or an explosion, lightning or
a launch into the sky); the most votes wins (no votes: solos with up to 4 players, duos with
more).
**Parties** (👥 Party) always end up on the same team. Up to 8 teams. 🤖 **Bots** fill empty
teams (up to 4 teams), so one player is enough to start: they hunt enemies, cross the bridges
to break beds, hack through block walls and respawn while their bed stands. Every match is on
a new **map**: 🌿 Meadow, 🌋 Volcano, ❄️ Frozen, 🍭 Candy, 🌌 Space, 🏜️ Desert (cacti and
sandstone), 👻 Haunted (dusk, gravestones, jack-o'-lanterns and ghost wisps) or 🏙️ Sky City
(tower blocks, street lamps, billboards). In the lobby, press **🗳️ Map & Bots** to vote for
the next map and how tough the bots are (🟢 Easy, 🟡 Normal, 🔴 Hard); with no map votes it's
a surprise, never the same twice in a row. Each team gets a sky island with:

- a **cloud bed** at the back. While it stands, you respawn 5 seconds after a knockout.
  Enemies break it by holding **E** on it for 2.5 seconds, but only if they can see it, so wall
  it in with blocks. Once it's gone, your next knockout puts you out: the 🎥 spectator camera
  follows the players and bots still fighting (◀ ▶ to switch, 🏠 for the sky box).
- a **generator** making 🟠 Copper (fast) and ⚪ Silver (slow). Stand on it to pick them up.
  The middle island has 💎 Storm Crystal and ⚡ Lightning Core generators that speed up at 6
  and 12 minutes.
- an **Item Shop** (🚀 Rocket Launchers and 🪝 Grappling Hooks too): blocks (Cloud Wool, Wood Planks, Stone Bricks, Obsidian), swords (Stone,
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
🕊️ Cloud Flight (Hurricane Hana, Typhoon Titan and Solar Flare Phoenix only). Support kits have team
powers: 💚 **Healing Rain** (heals you and teammates nearby: Healing Drizzle, Mending Monsoon),
🌉 **Instant Bridge** (a line of your team's blocks in front of you: Builder Breeze, Architect
Cyclone) and 🏹 **Arrow Volley** (a fan of free arrows: Arrow Gale, Sky Archer). **Rarer kits
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

## The lobby

- ⚔️ **1v1 duels:** open 👥 Party and press ⚔️ Duel next to anyone. You both get an iron sword
  in the arena; the first knockout wins Sparks (10 paid wins a day). Stepping out of the ring
  gives up; 90 seconds with no knockout is a draw.
- 🎯 **Training dummies:** hit them with your practice sword to see your damage.
- 🏆 **Weekend tournaments:** on Saturdays and Sundays a 1v1 bracket opens every 30 minutes
  (admins can start one any time). Press Join, then fight one duel at a time in the arena until
  one champion is left. Prizes: ⚡5,000 for the champion, 2,000 for the runner-up, 750 for the
  semifinals and 150 for joining, plus the 🏆 Tournament Champion title. The bracket shows on
  the board by the arena and in 📋 Bracket. Matches wait while a tournament is on.
- 🎁 **Mystery Chest:** open it once a day for Sparks, a kit, a new cosmetic, wheel spins or
  a rare ⚡10,000 jackpot.
- The **parkour** climbs around the outside of the island to a free Epic kit once a day.
- Falling off the lobby island just puts you back at the spawn.

## Cosmetics (🎨 Style)

- **You:** hats, trails, backs (wings, Arrow Quiver...), auras and 🐾 **pets** (a duckling,
  bunny, cat, corgi, cloud sheep, fox, deer or a flying storm dragon that walks after you
  everywhere, with moving legs, wagging tails and flapping wings). Every trail has a bright
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

## 🐉 The Storm Dragon

A few minutes into every match a Storm Dragon attacks the middle island. It circles overhead
spitting fireballs at anyone standing there, then lands to stomp: that's your chance to hit it
with swords (bows, fireballs and TNT work any time). A health bar shows at the top of the
screen. Everyone who hurts it gets Sparks, and the team that did the most damage gets Storm
Crystals and Lightning Cores. If nobody beats it in time, it flies away and comes back later.

## 🏝️ More lobby islands

- 🎯 **Games Island** (east, over a bridge; walk around the castle): the **Target Range** (40
  seconds to hit moving targets with a bow, bullseyes score more) and the **Parkour Race**
  (jump across floating platforms, touch both checkpoints, beat the clock). Both pay Sparks a
  few times a day, plus a bonus for a new personal best; the board shows the best in the server.
- 🏗️ **Base Island** (west): claim one of 8 plots and build with the 🔨 Builder (11 block types,
  up to 400 blocks): pick a block in the bar, click where it goes, 🧽 to remove. Your base is
  saved and comes back whenever you claim a plot. Anyone can visit.
  Behind every claimed plot is its owner's 🏆 **Trophy Room**: a golden cup and a plaque for
  each achievement they've earned.
- 🎨 **Build contests** on Base Island, all day: a theme (castle, rocket, treehouse...), 10
  minutes to build it, then 3 minutes to visit every base with 10+ blocks and give it 1-5 stars
  (the 🎨 chip at the top right). The top 3 win Sparks; entering and voting pay a little too.
  Winning counts toward the 🏗️ Master Builder title.
- 🐎 **Mounts:** ride a Pony, Night Mare, Unicorn, Flying Cloud or Storm Cloud around the lobby
  (🎨 Style → Mounts; press **H** or 🐎). Horses gallop fast; clouds fly (hold jump to rise).
  🐉 **Tame the Storm Dragon:** whoever does the most damage to the boss has a 15% chance to
  get it as a flying mount (certain on the 10th try).
- 🧭 **Guide Gale** by the castle gate walks new players through 8 steps (the chest, a match,
  the shop, a knockout, a bed, Base Island...). Each step pays Sparks; finishing gives an Epic
  kit, ⚡1,000 and the 🎓 Storm Scholar title.
- 🎁 **Gifts:** in 👥 Party, press 🎁 Gift next to someone to buy them a Sparks cosmetic they
  don't have yet (5 gifts = the 🎁 Generous title).
- 📰 **News board** in the courtyard: what's on right now and the latest updates (the newest
  also pops up once after an update).

## 🛍️ Shop Street

Out the castle's back gate and over the bridge: a cobbled street with 8 market stalls, each
with a seller. Talk to them to open the 🏪 Kit Market, 🌪️ Kit Stables, 🎨 Style Boutique,
🐾 Pet Shop, 😀 Emote Stage, 🖌️ Paint Shop, 🎡 Prize Wheel or 💎 Gem Shop.

## 💬 Taunts

Press **T** (or 💬) to say something in a speech bubble with a sound ("GG! 🤝", "Come get me! 😤"...).
Your character also speaks up by itself after a knockout, a broken bed or a win. Other
players' bubbles can be hidden in ⚙️ Settings.

## 😀 Emotes

Press **G** (or the 😀 button) for the emote wheel: Wave, Point, Cheer, Laugh and Sit are free;
Happy Hops, Spin, Dance, Backflip, Groove and Party Dance are bought with Sparks.

## 🖌️ Paint Shop

Pick a color for your sword blades and your armor (free). Your team's color still shows on
your armor's trim, tabard and plume.

## 🛡️ Clans

Make a clan with a name and a 2-4 letter tag (⚡5,000), invite people in your server, and
your tag shows in your clan's color above your head. Every match a member wins counts for the
clan, and the 🛡️ Clan window shows the **Top Clans** leaderboard. The leader can remove
members; the last one to leave closes the clan. Clans are saved across servers.

🎖️ **Clan Pass:** each season the clan earns Clan XP together (every member's matches, wins,
knockouts, beds and dragons count), and every member claims each of the 15 tiers' prizes for
themselves (Sparks and kits, up to a shiny Mythic kit).

## 🤝 Trading

In 👥 Party, press 🤝 Trade next to someone. Both of you add kits, cosmetics and Sparks, press
**Ready**, then **Confirm**. Changing an offer un-readies both sides, everything is checked
again right before the swap, and both profiles are saved straight after. Robux cosmetics
can't be traded, and trades only happen outside matches.

## 🌟 Challenges

A tough **Daily Challenge** (⚡1,500 + an Epic kit) and 5 **Weekly Challenges** (⚡2,500 + 400
battle pass stars each, new every Monday UTC): knockouts, final kills, beds, wins, blocks,
Crystals, lobby duels, lucky blocks and Storm Dragons. Finish all 5 for the weekly bonus: a
shiny Legendary kit, ⚡10,000 and the 🌟 Challenger title.

## More

- 🎁 **Rewards:** the 📅 28-day login calendar (claim a day each day you play; every 7th day
  is big, and day 28 gives a shiny Mythic kit, ⚡25,000 and the Loyal Legend title), 3 daily Bed Wars quests (knockouts, beds, wins, blocks,
  Crystals...), the Kit Collection, titles, codes and the daily prize wheel.
- **Titles** for wins, knockouts, final kills and beds broken; show one above your name.
- **Leaderboards** in the lobby for wins, knockouts and beds broken, with statues of the top 3.
- **Holiday events** (Halloween, Winter, Summer): every match earns the event currency, the
  lobby gets decorations, and the event shop sells exclusive kits.
- 👑 **Admin panel** (owner only): start or end a match, Admin Abuse (double Sparks), any
  weather, or Sparks for everyone. Admin Abuse also runs by itself once a week.
- 💎 **Robux shop:** VIP, Star Booster, Sparks, Golden Kit Crate, wheel spins, Battle Pass
  Premium, tier skips and Summon Rainbow Hour. Nothing sold makes you stronger in a match.

## 🐍 Sea Serpent

On the 🌊 Bubble Reef map the boss is the Sea Serpent instead of the Storm Dragon: a long
wriggling serpent that swims around the middle island spitting water bubbles, then rears up
and slams down a tidal wave. Same fight and loot (it can't be tamed); 5 wins earn 🐍 Serpent
Slayer.

## 🏪 Player Market

At the kiosk at the start of Shop Street: **💰 Sell** puts up to 5 of your Sparks cosmetics on
sale at your price, **🛒 Buy** shows everything on sale in the server. The seller gets the price
minus a 10% fee and the cosmetic moves to the buyer (Robux and free cosmetics can't be sold).
Listings end when you leave. Selling 10 earns 🏪 Merchant.

## 🌠 Shooting stars

At night, shooting stars streak across the sky and land somewhere on the lobby islands (you're
told where). Find the glowing Wish Star and hold E to wish for a surprise: Sparks, a kit or a
cosmetic. 3 wishes per star, 10 a day. 25 wishes earn 🌠 Star Gazer.

## 🏟️ 2v2 Arena Cup

Every 20 minutes (between matches) sign-ups open for a minute: tap 🏟️ at the top right. Party
members are paired together, everyone else in the order they joined. Pairs fight in the castle
arena in a knockout bracket (knock both enemies out or out of the ring). Winners get ⚡1,500
each and the 🏟️ Arena Champion title.

## 🧙 Classes

Before a match press **Class** (next to the mode vote) and pick one. It's saved for next
time.
- 🛡️ **Knight:** takes 15% less damage, swords hit 10% harder, spawns with a Stone Sword.
- 🏹 **Archer:** bow damage +25%, spawns with a Bow and 8 arrows.
- 🧱 **Builder:** spawns with 16 Cloud Wool and a better pickaxe.
- 💚 **Healer:** heals itself and teammates close by every 2 seconds; swords hit 10% softer.

🎓 **Class levels:** each class earns XP when you play it (matches, wins, knockouts, beds) and
levels up to 10. Every level makes its perks stronger (Knights take even less damage, Archers
hit harder and get more arrows, Builders get more wool, Healers heal more and further). The
class cards show your level and what it does now.

## 🌋 Disasters

A few minutes into normal matches (not the co-op modes), and every few minutes after:
☄️ **Meteor Shower** (red circles warn where they land; they break blocks and throw people),
🌋 **Earthquake** (the islands shake and placed blocks crumble) or 🌊 **Flood** (knee-deep
water everywhere for 30 seconds; falling off is safe while it lasts). A private server can
turn them off.

## 🎯 Bounties

Knock out 3 in a row without going down and a 🎯 bounty sign appears over you for everyone to
see. It grows with every knockout. Whoever knocks you out claims it (Sparks and Silver).
Claiming 10 earns the 🎯 Bounty Hunter title.

## 🏠 Base furniture

In the Builder bar press 🪑 to switch to furniture and building pieces: 🪜 stairs, ▬ half
blocks, 🪟 windows, 🚪 doors (two cells tall; anyone can open and close them), chair, table,
bed, sofa, lamp, plant, bookshelf, TV, rug, painting, fireplace and aquarium. 🔄 or **R** turns
it. It's saved with your base.

## 🧩 Puzzle rooms

On Base Island's south side, new every day: a 🌀 hedge maze (with a glass roof), a 🪟 glass
bridge (one glass in each pair breaks) and a 🔐 code door (the code's symbols are by the door;
each symbol's number is on a painting somewhere around the rooms). Each chest pays ⚡300 once
a day; all three pay a ⚡700 bonus. 7 full days earn 🧩 Puzzle Master.

## 🚤 Sky Boat Race

At the dock outside the castle gate, press **Race!**. Your boat flies where you look while you
hold forward. Fly through all 16 rings in order (the next one glows gold, with a line pointing
to it). Finishing pays a Games Island prize and the dock's board shows the best times.

## 🎭 Costume parties

Every 15 minutes or so a theme is announced (Spooky, Royal, Pirate...). Dress up in 🎨 Style and
stand on the stage at the end of Shop Street when time's up. Then everyone votes 1-5 stars on
each costume (🎭 at the top right, 👀 Look takes you to them). Winning earns 🎭 Fashion Star.

## 🌟 Hall of Legends

A marble hall outside the castle (back left) with golden statues of the world's #1 for wins,
knockouts, beds and rank, and plaques for every monthly champion.

## 🏰 Castle Defense

A co-op mode (everyone on one team). Your bed starts inside a stone castle with towers and a
gate. Storm monsters attack in 8 waves: ⛈️ Storm Imps, fast 🌪️ Twisters, big ⛰️ Storm
Golems and, in the last wave, the 👑 Storm King. They smash through walls to reach your bed.
After each wave everyone gets Sparks and 12 Stone Bricks to fix the walls. Beat every wave to
win.

## 🎣 Fishing

On the east side of Games Island there's a pond. Take a rod at the dock, click the water to
cast, and click again quickly when the bobber dips. There are 14 catches (from an Old Boot to
the Mythic 🐉 Storm Serpent). Each pays Sparks, up to 3,000 a day (Legendary and Mythic fish always pay in full). The 📖 Fish Book stand
shows what you've caught and your heaviest of each. Catching 100 earns 🎣 Master Angler.

## 🏅 Monthly season

Matches earn Season Points (finish 2, win 10, knockout 1, final knockout +2, bed 3). The board
by the castle gate shows this month's world top 10; your points show at the top right. When
the month ends, the top 100 win prizes the next time they join (#1: ⚡25,000, a Legendary kit
and the 🥇 Monthly Champion title).

## 🐾 Pets that help

The pet you bring helps in matches, and higher pet levels make it stronger: the Duckling and
Deer heal you, the Bunny and Cloud Sheep bring wool, the Cat finds Copper, the Corgi fetches
Silver, the Fox warns you when enemies are near your bed, and the Storm Dragon breathes fire
at enemies.

## 🗺️ Treasure hunt

Every day 5 treasures are buried around the lobby islands (the same for everyone). Your next
clue shows at the top right; find the dirt mound with a red ❌ and hold E to dig. Each pays
Sparks and finding all 5 gives a Rare kit. Finish 5 hunts for 🏴‍☠️ Treasure Hunter.

## 📸 Photo mode

In the lobby press 📸 (or P): the screen clears and the camera circles you (drag to turn,
scroll to zoom). Pick a pose, a frame and a filter, then 📷 Snap.

## 🎟️ Private match rules

In a private server its owner gets a 🎟️ button to pick the mode, map, special rule,
generator speed, bots and the dragon boss for every match (in Studio anyone can try it).

## 🎪 Weekly events

Every week (from Monday, UTC) every match gets a special rule: 🌙 Low Gravity, 🦣 Giant Mode,
💥 One Hit (every hit is a knockout), ⚡ Speed Rush or 💰 Double Sparks. The chip at the top
right and the news board say which one is on.

## 🪂 Gliders and parachutes

In the match item shop: the **Glider** (10 Silver, kept until the match ends) lets you hold
jump while falling to sail forward and sink slowly. A **Parachute** (6 Silver, carry up to 3)
opens by itself if you fall off the map and floats you back down over your own island.

## 👑 King of the Hill

A match mode you can vote for (duos): a glowing hill in the middle of the middle island. Every
second only one team stands on it, that team scores a point (two teams on it = contested). First
to 150 wins, or win the normal way by breaking beds. Bots go for the hill too.

## 🌙 Day and night

Every match starts in the morning and goes through dusk into night (a 12-minute cycle). At
night bots can't see as far and zombies get faster. A chip in the corner shows the time.

## 🧟 Zombie Survival

A match mode you can vote for: everyone is on one team, defending their bed on a haunted
island from 10 waves of zombies (a big Brute every 5th wave). You get 20 seconds to build walls
first. Zombies chase whoever is close, otherwise they go for the bed. Knocking out a zombie
gives Copper; every cleared wave gives Sparks. Survive them all to win.

## Blocks

Cloud Wool (your team's color), Wood Planks, 🪟 Sky Glass (see-through), 🟢 Bounce Slime (land
on it and you're thrown sky high), 🪜 Ladder (walk into it to climb), Stone Bricks and Obsidian.

## Controls in a match

Click with a sword (or the 🪄 **Knockback Stick**: barely hurts, sends people flying) to swing
(you can also hit placed blocks to break them), a pickaxe or axe to mine blocks, the bow to
shoot, a Fireball to throw it, a potion to drink it; hold a block or Storm TNT to see where it
goes and click to place it; **E** to open the Item Shop or break a bed; **Shift** for your
kit's power. Everyone always has at least a ⛏️ **Wood Pickaxe**: it breaks blocks, opens lucky
blocks and **digs into the ground** (not next to beds, generators, shops or spawns; holes are
filled back in after the match). Placed blocks and armor trim are in your **team's color**.
Hits show **damage numbers**, and knockouts and broken beds show in the **kill
feed** on the right.

On phones, big **⚔️ Use** (aims at the crosshair in the middle) and **🎒 Next item** buttons
sit next to the jump button.

## 🐾 Pet levels

The pet you bring gets XP when you play, win, knock someone out, break a bed or win a duel.
Every level (up to 10) makes it bigger and adds +1% to your match Sparks; at level 5 it
sparkles and at level 10 it glows gold. Its level shows on a tag above it.

## 📱 Invite friends

In 👥 Party, press **📱 Invite friends**. When someone new joins through your invite, they get
⚡1,000 and a Rare kit, and you get ⚡1,500 (it waits for you if you're in another server).
Invite 3 for the 📱 Recruiter title.

## 📊 Stats

Wins, matches, win rate, knockouts, final kills, K/D, beds broken, streaks, level, rank, duels,
parkour clears, Sparks earned and your **favorite weapon** (with a bar for every weapon).

## 🎵 Music and sounds

Sword slashes, hits, knockouts, explosions, broken beds and a victory fanfare. Music plays in
the lobby and in matches once you add songs to `Config.Music`: in Studio open Toolbox → Audio,
pick free Roblox-licensed music, right-click → Copy Asset ID, and paste the numbers into the
Lobby and Match lists.

## ⚙️ Settings

🌍 **Language** (Auto, English, Português, Español), music volume, camera follows the mouse, over-the-shoulder view, big phone buttons, sound effects volume,
sky extras, 🔕 fewer pop-up messages, ⚡ faster mode (hides small decorations on slow devices),
damage numbers, kill feed, fancy effects and other players' pets. Saved with your profile.

## 📋 Menu, messages and the Achievement Book

- The icon bar on the left is small now: 🎁 Rewards, 🎟️ Pass, 📋 **Menu** and ⚙️ Settings (and
  👑 Admin for you). The Menu (or **M**) has a tile for every window: Style, Kits, Class,
  Challenges, Achievements, Party, Clan, Stats, both markets, Fish Book, Emotes, Photo Mode,
  Messages, the Robux shop and Settings.
- Pop-ups merge repeats ("×2") and only a few show at once. With 🔕 *Fewer pop-up messages*,
  news meant for everyone only goes to 📜 **Messages** (warnings still pop up). Every message
  is kept in 📜 Messages (Menu).
- 🏅 **Achievement Book** (Menu): every achievement and title with progress bars, "Almost
  there" first; wear titles right from it.

## 📅 Lobby events

The 🎨 Build Contest, 🎭 Costume Party and 🏟️ 2v2 Arena Cup take turns, one at a time, with a
4-minute break between them. When nothing is on, a chip at the top right says what's next and
when.

## 🎁 Starter pack

Brand-new players (no matches yet) get a welcome window with a gift (⚡1,000, a Rare kit and a
🦆 Duckling pet) and a short list of what to do first. Players who already played never see
it.

## 🌍 Languages

The main screens (Menu, icon bar, ⚙️ Settings, welcome and welcome-back windows, the
tutorial, the top-right chips, Guide Gale's steps, treasure clues, the Achievement Book and the
loading tips) come in English, Portuguese and Spanish (`src/shared/Lang.luau`). ⚙️ Settings →
Language picks one; *Auto* follows the player's Roblox language. Server messages (pop-ups,
signs, the news board) are still English: turn on Roblox's automatic translation (Creator
Dashboard → your game → Localization) to cover them too.

## 🎓 First-match tutorial

In a new player's very first match, a banner above the resources walks them through it one
step at a time: protect your bed, pick up resources at the generator, buy blocks, place them,
then go break an enemy bed. Each step moves on by itself once it's done; *Skip* ends it. It
never shows again after the first match.

## 👋 Welcome back

Players who were away a day or more (or missed an update) get a window when they join: how
long they were away, every update they missed (up to 4, newest in full) and what's waiting
today (daily reward, new treasure clues, new puzzle rooms, this week's special rule).
Brand-new players skip it.

## ⚖️ Balance

Matches are the main way to earn Sparks (about ⚡2,000 an hour); lobby activities are a
daily bonus on top. Daily limits: fishing ⚡3,000 (Legendary and Mythic fish always pay in
full), 5 mini-game prizes (range, parkour race, boat race), 10 paid duel wins, 3 puzzle rooms,
5 treasure spots, 10 wishes. The big items (⚡50,000-100,000 cosmetics, Mythic kits) take a
few days of play. Class and pet levels reach 10 in about 60-70 matches.

## 🎨 Window look

Every window uses the same dark panel, rounded corners, blue border, gold title and red ✕,
and pops open with a small bounce (`WindowStyle`), so new windows match automatically.

## 👑 Admin panel

Four tabs (only you, the game's owner, see it; anyone in Studio):
- ⚔️ **Match:** start or end a match, a 1v1 tournament, Admin Abuse, any weather, Sparks for
  everyone.
- 🧪 **Test:** start the boss now (in a match), any disaster, a build contest, a costume party,
  the Arena Cup, skip a contest/party phase, night for 3 minutes, a shooting star, any special
  rule, and start your own guide, treasure hunt, puzzles, wishes and starter pack over.
- 🗂️ **Players:** look anyone up by name or user id (even offline), give someone Sparks, and
  restore an online player's newest backup (tap twice).
- 📈 **Stats:** what people did today or in the last 7 days (matches by mode and map, fish,
  boat races, puzzles, events, market sales…). The same counts go to Roblox's Creator
  Dashboard → Analytics → Custom events.

## 🛡️ Saving

Profiles are session-locked (never open on two servers). A failed save is retried, a profile
that looks broken is never saved over a good one, and the last 3 copies of every profile are
kept in a separate backup store (every 10 minutes and when you leave).

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
- 👑 Admin → 🧪 **Test** starts every timed feature right away (boss, disasters, lobby events,
  night, shooting stars...).
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
              SettingsData, ChallengeData, PaintData, EmoteData, PetLevels,
              ClanPassData, BaseData, NewsData, TauntData, EventData (weekly events),
              Lang (English, Portuguese, Spanish), GuideData (Guide Gale), ContestData (build contests), FishData, MonthlyData,
              PetHelpers, CustomData (private match rules), TreasureData, ClassData,
              PuzzleData, BoatData, Remotes, Format, Signal
src/server/   Main.server.luau starts the services in order
  Services/   DataService, MatchService (rounds, teams, beds, generators), CombatService,
              GadgetService (TNT, fireballs, potions, pickaxes, axes), PartyService,
              MapService, ProgressionService (levels, ranked, streaks, dances, achievements),
              BlockService, ItemShopService, KitService, WeatherService, MovementService
              (falling off), IncomeService (Sparks), IndexService (Kit Collection),
              SeasonService, RewardService, MarketService, SpinService, DailyService,
              TitleService, HolidayService, CosmeticService (and pets), ObbyService (lobby
              parkour), LobbyService (duels, training dummies), LuckyService (Lucky
              Blocks mode), SettingsService,
              CommunityService (codes, group, likes), LeaderboardService, AdminService,
              MonetizationService, BotService (bots), TournamentService,
              ChestService (Mystery Chest), StatsService, KitPowerService (heal, bridge
              and volley powers), BossService (Storm Dragon), ClanService, TradeService,
              VoteService (map and bot votes), ChallengeService, PaintService,
              EmoteService, PetLevelService, InviteService, ZombieService, HillService,
              NewsService, TauntService, MountService (and dragon taming), MiniGameService,
              BaseService (and trophy rooms), EventService, GiftService, GuideService,
              ContestService, FishingService, MonthlyService, PetHelperService,
              CustomMatchService, TreasureService (ZombieService also runs Castle Defense),
              ClassService, DisasterService, BountyService, PuzzleService, BoatService,
              CostumeService, LegendsService, PlayerShopService, WishService,
              ArenaCupService (BossService also runs the Sea Serpent), LobbyEventService,
              UsageService (play stats), StarterService, TutorialService
  Modules/    WorldBuilder (terrain islands, the castle lobby, bridges, trees, forecast TV),
              ItemModels (weapons and items), PetModels, MountModels (and the sky boat),
              FurnitureModels, StormModel (kit
              storms), Effects,
              Juice, Notify, Codes, Usage (play stats), Busy (who's in a match, fight or race)
src/first/    LoadingScreen (runs first: the loading screen)
src/client/   Main.client.luau starts the controllers
  Controllers/ HUD, MatchHUD (and the mode vote), CameraController, ItemShop, Kits, Party, KitController (Shift powers), KitFollower,
               WeaponController, BlockController, Aim, Shop, Market, HolidayShop, Style,
               Season, Rewards, AdminPanel, ForecastController, StormAnimator, FlashyFx,
               AmbientController, JuiceController, Settings, DamageFeed (damage numbers,
               kill feed), PetFollower, TouchControls (phone buttons), Stats,
               MusicController, TournamentHUD, Vote, SpectateController (follow players
               after you're out), BossHUD, Challenges, Clan, Trade, BlockPhysics (slime
               and ladders), Paint, EmoteWheel, ShopStreet, ZombieHUD, HillHUD,
               NewsPopup (what's new and welcome back), DayNightHUD, TauntPicker, MountController, MiniGameHUD,
               BaseBuilder, EventClient (low gravity), GlideController, GuideTracker,
               ContestClient, Gift, FishingController, FishBook, MonthlyChip, PetHelpChip,
               CustomMatch, TreasureChip, PhotoMode, ClassPicker, DisasterChip, PuzzleCode,
               BoatController, CostumeClient, PlayerShop, ArenaCupClient, LobbyEventChip,
               AchievementBook, Menu, StarterPack, TutorialController, WindowStyle,
               LowDetail (faster mode), Toasts
               (and the 📜 Messages log), Sfx, UI
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
