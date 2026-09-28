--!strict
-- 🌍 Translations: English, Portuguese (Brazil) and Spanish for the main
-- screens (the Menu, icon bar, Settings, welcome and welcome-back windows,
-- the tutorial, the top-right chips, guide steps and treasure clues). The
-- language is ⚙️ Settings → Language: "Auto" follows the player's Roblox
-- language. Anything without a translation stays in English; turning on
-- Roblox's automatic translation (Creator Dashboard → Localization) covers
-- the rest of the game's text.
--
-- Lang.t(key) gives the text for the player's language; Lang.f(key, vars)
-- also fills in {name}-style blanks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lang = {}

type Entry = { en: string, pt: string, es: string }

local S: { [string]: Entry } = {
	-- 📋 Menu and icon bar
	["menu.title"] = { en = "📋 Menu", pt = "📋 Menu", es = "📋 Menú" },
	["bar.rewards"] = { en = "Rewards", pt = "Prêmios", es = "Premios" },
	["bar.pass"] = { en = "Pass", pt = "Passe", es = "Pase" },
	["bar.menu"] = { en = "Menu", pt = "Menu", es = "Menú" },
	["bar.settings"] = { en = "Settings", pt = "Ajustes", es = "Ajustes" },
	["bar.admin"] = { en = "Admin", pt = "Admin", es = "Admin" },
	["tile.style"] = { en = "Style", pt = "Estilo", es = "Estilo" },
	["tile.style.hint"] = {
		en = "Hats, trails, pets, mounts…",
		pt = "Chapéus, rastros, pets, montarias…",
		es = "Sombreros, estelas, mascotas, monturas…",
	},
	["tile.kits"] = { en = "Kits", pt = "Kits", es = "Kits" },
	["tile.kits.hint"] = {
		en = "Pick the kit you bring",
		pt = "Escolha o kit que você leva",
		es = "Elige el kit que llevas",
	},
	["tile.class"] = { en = "Class", pt = "Classe", es = "Clase" },
	["tile.class.hint"] = {
		en = "Knight, Archer, Builder, Healer",
		pt = "Cavaleiro, Arqueiro, Construtor, Curandeiro",
		es = "Caballero, Arquero, Constructor, Sanador",
	},
	["tile.challenges"] = { en = "Challenges", pt = "Desafios", es = "Desafíos" },
	["tile.challenges.hint"] = {
		en = "Daily and weekly goals",
		pt = "Metas diárias e semanais",
		es = "Metas diarias y semanales",
	},
	["tile.achievements"] = { en = "Achievements", pt = "Conquistas", es = "Logros" },
	["tile.achievements.hint"] = {
		en = "Every goal and title",
		pt = "Todas as metas e títulos",
		es = "Todas las metas y títulos",
	},
	["tile.rewards"] = { en = "Rewards", pt = "Recompensas", es = "Recompensas" },
	["tile.rewards.hint"] = {
		en = "Daily calendar, quests, codes",
		pt = "Calendário diário, missões, códigos",
		es = "Calendario diario, misiones, códigos",
	},
	["tile.pass"] = { en = "Battle Pass", pt = "Passe de Batalha", es = "Pase de Batalla" },
	["tile.pass.hint"] = { en = "Season rewards", pt = "Recompensas da temporada", es = "Recompensas de temporada" },
	["tile.party"] = { en = "Party & Friends", pt = "Grupo e Amigos", es = "Grupo y Amigos" },
	["tile.party.hint"] = {
		en = "Team up, duel, trade, gift",
		pt = "Formar equipe, duelar, trocar, presentear",
		es = "Formar equipo, duelar, intercambiar, regalar",
	},
	["tile.clan"] = { en = "Clan", pt = "Clã", es = "Clan" },
	["tile.clan.hint"] = { en = "Your clan and its pass", pt = "Seu clã e o passe dele", es = "Tu clan y su pase" },
	["tile.stats"] = { en = "Stats", pt = "Estatísticas", es = "Estadísticas" },
	["tile.stats.hint"] = { en = "How you've been doing", pt = "Como você está indo", es = "Cómo te va" },
	["tile.market"] = { en = "Kit Market", pt = "Mercado de Kits", es = "Mercado de Kits" },
	["tile.market.hint"] = { en = "Buy kits and crates", pt = "Compre kits e caixas", es = "Compra kits y cajas" },
	["tile.playermarket"] = { en = "Player Market", pt = "Mercado dos Jogadores", es = "Mercado de Jugadores" },
	["tile.playermarket.hint"] = {
		en = "Buy and sell cosmetics",
		pt = "Compre e venda cosméticos",
		es = "Compra y vende cosméticos",
	},
	["tile.fish"] = { en = "Fish Book", pt = "Livro dos Peixes", es = "Libro de Peces" },
	["tile.fish.hint"] = { en = "Your catches", pt = "Suas pescas", es = "Tus capturas" },
	["tile.emotes"] = { en = "Emotes", pt = "Emotes", es = "Emotes" },
	["tile.emotes.hint"] = { en = "Dance and wave (G)", pt = "Dance e acene (G)", es = "Baila y saluda (G)" },
	["tile.photo"] = { en = "Photo Mode", pt = "Modo Foto", es = "Modo Foto" },
	["tile.photo.hint"] = { en = "Poses and frames (P)", pt = "Poses e molduras (P)", es = "Poses y marcos (P)" },
	["tile.messages"] = { en = "Messages", pt = "Mensagens", es = "Mensajes" },
	["tile.messages.hint"] = {
		en = "Everything that popped up",
		pt = "Tudo o que apareceu",
		es = "Todo lo que apareció",
	},
	["tile.robux"] = { en = "Robux Shop", pt = "Loja de Robux", es = "Tienda de Robux" },
	["tile.robux.hint"] = { en = "VIP, boosts and more", pt = "VIP, bônus e mais", es = "VIP, mejoras y más" },
	["tile.settings"] = { en = "Settings", pt = "Configurações", es = "Ajustes" },
	["tile.settings.hint"] = {
		en = "Camera, sound, faster mode",
		pt = "Câmera, som, modo rápido",
		es = "Cámara, sonido, modo rápido",
	},
	["tile.admin"] = { en = "Admin", pt = "Admin", es = "Admin" },
	["tile.admin.hint"] = {
		en = "Owner tools and tests",
		pt = "Ferramentas e testes do dono",
		es = "Herramientas y pruebas del dueño",
	},

	-- ⚙️ Settings
	["settings.title"] = { en = "⚙️ Settings", pt = "⚙️ Configurações", es = "⚙️ Ajustes" },
	["settings.on"] = { en = "ON", pt = "LIGADO", es = "SÍ" },
	["settings.off"] = { en = "OFF", pt = "DESLIGADO", es = "NO" },
	["setting.language.name"] = { en = "🌍 Language", pt = "🌍 Idioma", es = "🌍 Idioma" },
	["setting.language.hint"] = {
		en = "Auto uses your Roblox language. Some text changes after you rejoin.",
		pt = "Auto usa o idioma do seu Roblox. Alguns textos mudam quando você entra de novo.",
		es = "Auto usa el idioma de tu Roblox. Algunos textos cambian al volver a entrar.",
	},
	["setting.cameraLock.name"] = {
		en = "🖱️ Camera follows the mouse",
		pt = "🖱️ Câmera segue o mouse",
		es = "🖱️ La cámara sigue al ratón",
	},
	["setting.cameraLock.hint"] = {
		en = "Off: hold right-click to turn the camera, like normal Roblox.",
		pt = "Desligado: segure o botão direito para girar a câmera, como no Roblox normal.",
		es = "Apagado: mantén el clic derecho para girar la cámara, como en Roblox normal.",
	},
	["setting.shoulder.name"] = {
		en = "📷 Over-the-shoulder view",
		pt = "📷 Visão por cima do ombro",
		es = "📷 Vista sobre el hombro",
	},
	["setting.shoulder.hint"] = {
		en = "The camera sits a little to your right so you can aim past yourself.",
		pt = "A câmera fica um pouco à sua direita para você mirar melhor.",
		es = "La cámara se pone un poco a tu derecha para apuntar mejor.",
	},
	["setting.phoneButtons.name"] = {
		en = "📱 Big fight buttons",
		pt = "📱 Botões grandes de luta",
		es = "📱 Botones grandes de pelea",
	},
	["setting.phoneButtons.hint"] = {
		en = "Big ⚔️ Use and 🎒 Next item buttons next to the jump button.",
		pt = "Botões grandes ⚔️ Usar e 🎒 Próximo item ao lado do botão de pulo.",
		es = "Botones grandes ⚔️ Usar y 🎒 Siguiente objeto junto al botón de salto.",
	},
	["setting.music.name"] = { en = "🎵 Music", pt = "🎵 Música", es = "🎵 Música" },
	["setting.music.hint"] = {
		en = "Songs in the lobby and during matches.",
		pt = "Músicas no lobby e durante as partidas.",
		es = "Canciones en el lobby y durante las partidas.",
	},
	["setting.sfx.name"] = { en = "🔊 Sound effects", pt = "🔊 Efeitos sonoros", es = "🔊 Efectos de sonido" },
	["setting.sfx.hint"] = {
		en = "How loud hits, pops and chimes are.",
		pt = "O volume dos golpes, estalos e sininhos.",
		es = "El volumen de golpes, pops y campanitas.",
	},
	["setting.ambient.name"] = {
		en = "🕊️ Birds, balloons and floating islets",
		pt = "🕊️ Pássaros, balões e ilhotas flutuantes",
		es = "🕊️ Pájaros, globos e islotes flotantes",
	},
	["setting.ambient.hint"] = {
		en = "Little extras in the sky (only on your screen).",
		pt = "Enfeites no céu (só na sua tela).",
		es = "Detalles en el cielo (solo en tu pantalla).",
	},
	["setting.quietMessages.name"] = {
		en = "🔕 Fewer pop-up messages",
		pt = "🔕 Menos mensagens na tela",
		es = "🔕 Menos mensajes emergentes",
	},
	["setting.quietMessages.hint"] = {
		en = "News for everyone goes to 📜 Messages (📋 Menu) instead of popping up. Warnings still pop up.",
		pt = "Avisos para todos vão para 📜 Mensagens (📋 Menu) em vez de aparecer. Alertas ainda aparecem.",
		es = "Las noticias para todos van a 📜 Mensajes (📋 Menú) en lugar de aparecer. Las alertas sí aparecen.",
	},
	["setting.lowDetail.name"] = {
		en = "⚡ Faster mode (less detail)",
		pt = "⚡ Modo rápido (menos detalhes)",
		es = "⚡ Modo rápido (menos detalle)",
	},
	["setting.lowDetail.hint"] = {
		en = "Hides flowers, bushes and little decorations so the game runs smoother on slow devices.",
		pt = "Esconde flores, arbustos e enfeites para o jogo rodar melhor em aparelhos lentos.",
		es = "Oculta flores, arbustos y adornos para que el juego vaya mejor en dispositivos lentos.",
	},
	["setting.damageNumbers.name"] = {
		en = "💥 Damage numbers",
		pt = "💥 Números de dano",
		es = "💥 Números de daño",
	},
	["setting.damageNumbers.hint"] = {
		en = "Numbers pop up when you hit someone.",
		pt = "Números aparecem quando você acerta alguém.",
		es = "Aparecen números cuando golpeas a alguien.",
	},
	["setting.killFeed.name"] = { en = "📰 Kill feed", pt = "📰 Lista de nocautes", es = "📰 Lista de derribos" },
	["setting.killFeed.hint"] = {
		en = "Knockouts and broken beds on the right side of the screen.",
		pt = "Nocautes e camas quebradas no lado direito da tela.",
		es = "Derribos y camas rotas en el lado derecho de la pantalla.",
	},
	["setting.effects.name"] = { en = "✨ Fancy effects", pt = "✨ Efeitos especiais", es = "✨ Efectos especiales" },
	["setting.effects.hint"] = {
		en = "Glow, sun rays and sparkly animations. Turn off if your game is slow.",
		pt = "Brilhos, raios de sol e animações. Desligue se o jogo estiver lento.",
		es = "Brillos, rayos de sol y animaciones. Apágalo si el juego va lento.",
	},
	["setting.taunts.name"] = {
		en = "💬 Other players' taunts",
		pt = "💬 Provocações dos outros",
		es = "💬 Burlas de otros jugadores",
	},
	["setting.taunts.hint"] = {
		en = "Speech bubbles over other players' heads.",
		pt = "Balões de fala sobre a cabeça dos outros jogadores.",
		es = "Bocadillos sobre la cabeza de otros jugadores.",
	},
	["setting.othersPets.name"] = {
		en = "🐾 Show other players' pets",
		pt = "🐾 Mostrar pets dos outros",
		es = "🐾 Ver mascotas de otros",
	},
	["setting.othersPets.hint"] = {
		en = "Your own pet always shows.",
		pt = "Seu próprio pet sempre aparece.",
		es = "Tu propia mascota siempre se ve.",
	},

	-- 🎁 Welcome window (new players)
	["starter.title"] = {
		en = "👋 Welcome to Bottle a Storm!",
		pt = "👋 Bem-vindo ao Bottle a Storm!",
		es = "👋 ¡Bienvenido a Bottle a Storm!",
	},
	["starter.gift"] = {
		en = "🎁 Your welcome gift: ⚡1,000 Sparks, a Rare kit and a 🦆 Duckling pet that heals you in matches!",
		pt = "🎁 Seu presente de boas-vindas: ⚡1.000 Sparks, um kit Raro e um pet 🦆 Patinho que te cura nas partidas!",
		es = "🎁 Tu regalo de bienvenida: ⚡1.000 Sparks, un kit Raro y una mascota 🦆 Patito que te cura en las partidas.",
	},
	["starter.first"] = { en = "What to do first:", pt = "O que fazer primeiro:", es = "Qué hacer primero:" },
	["starter.step1"] = {
		en = "⚔️ Play a match: vote for a mode at the top, it starts by itself",
		pt = "⚔️ Jogue uma partida: vote em um modo lá em cima, ela começa sozinha",
		es = "⚔️ Juega una partida: vota un modo arriba, empieza sola",
	},
	["starter.step2"] = {
		en = "🛏️ Protect your bed with blocks, break the other teams' beds",
		pt = "🛏️ Proteja sua cama com blocos e quebre as camas dos outros times",
		es = "🛏️ Protege tu cama con bloques y rompe las camas de los otros equipos",
	},
	["starter.step3"] = {
		en = "🧭 Talk to Guide Gale by the gate for a step-by-step quest",
		pt = "🧭 Fale com a Guia Gale no portão para uma missão passo a passo",
		es = "🧭 Habla con la Guía Gale en la puerta para una misión paso a paso",
	},
	["starter.step4"] = {
		en = "🧙 Pick a class (the Class button next to the mode vote)",
		pt = "🧙 Escolha uma classe (o botão Classe ao lado da votação)",
		es = "🧙 Elige una clase (el botón Clase junto a la votación)",
	},
	["starter.step5"] = {
		en = "📋 Everything else is in the Menu (or press M)",
		pt = "📋 Todo o resto está no Menu (ou aperte M)",
		es = "📋 Todo lo demás está en el Menú (o pulsa M)",
	},
	["starter.claim"] = {
		en = "🎁 Claim my gift & play!",
		pt = "🎁 Pegar meu presente e jogar!",
		es = "🎁 ¡Recoger mi regalo y jugar!",
	},

	-- 🎓 First-match tutorial
	["tutorial.title"] = { en = "🎓 Tutorial", pt = "🎓 Tutorial", es = "🎓 Tutorial" },
	["tutorial.skip"] = { en = "Skip", pt = "Pular", es = "Saltar" },
	["tutorial.bed"] = {
		en = "🛏️ This is your island. Your bed is behind your spawn: while it stands, you come back after a knockout. Keep it safe!",
		pt = "🛏️ Esta é a sua ilha. Sua cama fica atrás de onde você nasce: enquanto ela existir, você volta depois de um nocaute. Proteja-a!",
		es = "🛏️ Esta es tu isla. Tu cama está detrás de donde apareces: mientras siga en pie, vuelves tras un derribo. ¡Protégela!",
	},
	["tutorial.generator"] = {
		en = "⛏️ Stand on your generator (the glowing pad near your spawn) to pick up Copper.",
		pt = "⛏️ Fique em cima do seu gerador (a plataforma brilhante perto de onde você nasce) para pegar Cobre.",
		es = "⛏️ Párate sobre tu generador (la plataforma brillante cerca de donde apareces) para recoger Cobre.",
	},
	["tutorial.shop"] = {
		en = "🛒 Walk to the shopkeeper on your island and buy Cloud Wool (4 Copper).",
		pt = "🛒 Vá até o vendedor na sua ilha e compre Lã de Nuvem (4 Cobre).",
		es = "🛒 Ve al vendedor de tu isla y compra Lana de Nube (4 Cobre).",
	},
	["tutorial.place"] = {
		en = "🧱 Hold the wool and click to place blocks around your bed.",
		pt = "🧱 Segure a lã e clique para colocar blocos em volta da sua cama.",
		es = "🧱 Sujeta la lana y haz clic para poner bloques alrededor de tu cama.",
	},
	["tutorial.attack"] = {
		en = "⚔️ Now build a bridge to an enemy island and break their bed! Good luck!",
		pt = "⚔️ Agora faça uma ponte até uma ilha inimiga e quebre a cama deles! Boa sorte!",
		es = "⚔️ ¡Ahora construye un puente hasta una isla enemiga y rompe su cama! ¡Suerte!",
	},

	-- 👋 Welcome back and what's new
	["back.title"] = {
		en = "👋 Welcome back!",
		pt = "👋 Que bom te ver de novo!",
		es = "👋 ¡Bienvenido de nuevo!",
	},
	["back.away"] = {
		en = "You were away for {days} days.",
		pt = "Você ficou fora por {days} dias.",
		es = "Estuviste fuera {days} días.",
	},
	["back.new"] = {
		en = "📰 New since you last played:",
		pt = "📰 Novidades desde a última vez:",
		es = "📰 Novedades desde la última vez:",
	},
	["back.waiting"] = { en = "Waiting for you:", pt = "Esperando por você:", es = "Te espera:" },
	["back.daily"] = {
		en = "🎁 A daily reward to claim (🎁 Rewards)",
		pt = "🎁 Uma recompensa diária para pegar (🎁 Prêmios)",
		es = "🎁 Una recompensa diaria (🎁 Premios)",
	},
	["back.treasure"] = {
		en = "🗺️ New treasure hunt clues",
		pt = "🗺️ Novas pistas da caça ao tesouro",
		es = "🗺️ Nuevas pistas de la búsqueda del tesoro",
	},
	["back.puzzles"] = {
		en = "🧩 New puzzle rooms on Base Island",
		pt = "🧩 Novas salas de enigmas na Ilha das Bases",
		es = "🧩 Nuevas salas de acertijos en la Isla de Bases",
	},
	["back.rule"] = {
		en = "🎪 Special rule now: {rule}",
		pt = "🎪 Regra especial agora: {rule}",
		es = "🎪 Regla especial ahora: {rule}",
	},
	["back.close"] = { en = "Let's play!", pt = "Vamos jogar!", es = "¡A jugar!" },
	["news.title"] = { en = "📰 What's new", pt = "📰 Novidades", es = "📰 Novedades" },

	-- Chips at the top right
	["chip.next"] = {
		en = "📅 Next: {event} in {time}",
		pt = "📅 Próximo: {event} em {time}",
		es = "📅 Siguiente: {event} en {time}",
	},
	["chip.nextSoon"] = {
		en = "📅 Next: {event} soon",
		pt = "📅 Próximo: {event} em breve",
		es = "📅 Siguiente: {event} pronto",
	},
	["chip.week"] = { en = "🎪 This week: {name}", pt = "🎪 Esta semana: {name}", es = "🎪 Esta semana: {name}" },
	["chip.season"] = {
		en = "🏅 Season: {points} pts",
		pt = "🏅 Temporada: {points} pts",
		es = "🏅 Temporada: {points} pts",
	},
	["chip.treasure"] = {
		en = "🗺️ Treasure {n}/{total}: {clue}",
		pt = "🗺️ Tesouro {n}/{total}: {clue}",
		es = "🗺️ Tesoro {n}/{total}: {clue}",
	},
	["chip.guideNew"] = {
		en = "🧭 New? Talk to Guide Gale by the gate!",
		pt = "🧭 Novo aqui? Fale com a Guia Gale no portão!",
		es = "🧭 ¿Eres nuevo? ¡Habla con la Guía Gale en la puerta!",
	},
	["chip.meteors"] = {
		en = "☄️ METEOR SHOWER! Watch for red circles",
		pt = "☄️ CHUVA DE METEOROS! Cuidado com os círculos vermelhos",
		es = "☄️ ¡LLUVIA DE METEOROS! Cuidado con los círculos rojos",
	},
	["chip.quake"] = {
		en = "🌋 EARTHQUAKE! Blocks are crumbling",
		pt = "🌋 TERREMOTO! Os blocos estão caindo",
		es = "🌋 ¡TERREMOTO! Los bloques se derrumban",
	},
	["chip.flood"] = {
		en = "🌊 FLOOD! Falling off is safe for now",
		pt = "🌊 ENCHENTE! Cair da ilha é seguro por enquanto",
		es = "🌊 ¡INUNDACIÓN! Caerse es seguro por ahora",
	},

	-- 🧭 Guide Gale's steps
	["guide.talk"] = {
		en = "Talk to Guide Gale by the castle gate",
		pt = "Fale com a Guia Gale no portão do castelo",
		es = "Habla con la Guía Gale en la puerta del castillo",
	},
	["guide.chest"] = {
		en = "Open the 🎁 Daily Mystery Chest in the castle",
		pt = "Abra o 🎁 Baú Misterioso Diário no castelo",
		es = "Abre el 🎁 Cofre Misterioso Diario en el castillo",
	},
	["guide.collect"] = {
		en = "Join a match and pick up resources at your generator",
		pt = "Entre em uma partida e pegue recursos no seu gerador",
		es = "Entra en una partida y recoge recursos en tu generador",
	},
	["guide.buy"] = {
		en = "Buy something from the item shop on your island",
		pt = "Compre algo na loja de itens da sua ilha",
		es = "Compra algo en la tienda de tu isla",
	},
	["guide.knockout"] = {
		en = "Knock out an enemy (bots count!)",
		pt = "Nocauteie um inimigo (bots contam!)",
		es = "Derriba a un enemigo (¡los bots cuentan!)",
	},
	["guide.bed"] = { en = "Break an enemy bed", pt = "Quebre uma cama inimiga", es = "Rompe una cama enemiga" },
	["guide.play"] = {
		en = "Play a match to the end",
		pt = "Jogue uma partida até o fim",
		es = "Juega una partida hasta el final",
	},
	["guide.base"] = {
		en = "Claim a plot on 🏗️ Base Island (over the west bridge)",
		pt = "Pegue um terreno na 🏗️ Ilha das Bases (pela ponte oeste)",
		es = "Reclama un terreno en la 🏗️ Isla de Bases (por el puente oeste)",
	},

	-- 🗺️ Treasure clues
	["clue.TV"] = {
		en = "The weather is always on here. Look behind the big screen.",
		pt = "O tempo está sempre passando aqui. Procure atrás da tela grande.",
		es = "Aquí siempre dan el tiempo. Busca detrás de la pantalla grande.",
	},
	["clue.Chest"] = {
		en = "Next to a box that opens once a day.",
		pt = "Ao lado de uma caixa que abre uma vez por dia.",
		es = "Junto a una caja que se abre una vez al día.",
	},
	["clue.Arena"] = {
		en = "Where 1v1 fights happen. Check the edge of the ring.",
		pt = "Onde acontecem as lutas 1x1. Olhe na beirada do ringue.",
		es = "Donde son los duelos 1 contra 1. Mira en el borde del ring.",
	},
	["clue.Dummies"] = {
		en = "Behind the ones who never fight back.",
		pt = "Atrás daqueles que nunca revidam.",
		es = "Detrás de los que nunca devuelven el golpe.",
	},
	["clue.News"] = {
		en = "Behind the board that tells you what's new.",
		pt = "Atrás do quadro que conta as novidades.",
		es = "Detrás del tablero que cuenta las novedades.",
	},
	["clue.Guide"] = {
		en = "Right behind the friendly guide by the gate.",
		pt = "Logo atrás da guia simpática no portão.",
		es = "Justo detrás de la guía amable de la puerta.",
	},
	["clue.Signpost"] = {
		en = "Outside the castle gate, by the signs pointing the way.",
		pt = "Fora do portão do castelo, perto das placas que mostram o caminho.",
		es = "Fuera de la puerta del castillo, junto a los carteles que señalan el camino.",
	},
	["clue.Pond"] = {
		en = "On the sandy shore where the fish bite.",
		pt = "Na areia da margem onde os peixes mordem a isca.",
		es = "En la orilla de arena donde pican los peces.",
	},
	["clue.Range"] = {
		en = "Where the archers stand on Games Island.",
		pt = "Onde os arqueiros ficam na Ilha dos Jogos.",
		es = "Donde se ponen los arqueros en la Isla de Juegos.",
	},
	["clue.Parkour"] = {
		en = "Where the parkour race begins.",
		pt = "Onde começa a corrida de parkour.",
		es = "Donde empieza la carrera de parkour.",
	},
	["clue.Bases"] = {
		en = "In the middle of the island where people build.",
		pt = "No meio da ilha onde as pessoas constroem.",
		es = "En medio de la isla donde la gente construye.",
	},
	["clue.Street"] = {
		en = "On the cobbles of the street full of shops.",
		pt = "Nas pedras da rua cheia de lojas.",
		es = "En los adoquines de la calle llena de tiendas.",
	},
	["clue.Bridge"] = {
		en = "Where the bridge to the shops lands.",
		pt = "Onde termina a ponte que vai para as lojas.",
		es = "Donde llega el puente hacia las tiendas.",
	},
	["clue.Season"] = {
		en = "In front of the board of this month's best.",
		pt = "Na frente do quadro dos melhores do mês.",
		es = "Frente al tablero de los mejores del mes.",
	},

	-- Windows and buttons
	["window.messages"] = { en = "📜 Messages", pt = "📜 Mensagens", es = "📜 Mensajes" },
	["window.achievements"] = {
		en = "🏅 Achievement Book",
		pt = "🏅 Livro de Conquistas",
		es = "🏅 Libro de Logros",
	},
	["achievements.almost"] = { en = "⏳ Almost there", pt = "⏳ Quase lá", es = "⏳ Casi" },
	["achievements.done"] = { en = "✅ Done", pt = "✅ Feitas", es = "✅ Hechos" },
	["achievements.all"] = { en = "📚 All", pt = "📚 Todas", es = "📚 Todos" },
	["achievements.wear"] = { en = "Wear", pt = "Usar", es = "Usar" },
	["achievements.wearing"] = { en = "Wearing", pt = "Usando", es = "Usando" },
	["vote.label"] = { en = "Vote:", pt = "Vote:", es = "Vota:" },
	["vote.mapBots"] = { en = "🗳️ Map & Bots", pt = "🗳️ Mapa e Bots", es = "🗳️ Mapa y Bots" },
	["vote.class"] = { en = "Class: {class}", pt = "Classe: {class}", es = "Clase: {class}" },
}

local LANGS = { [1] = "en", [2] = "pt", [3] = "es" }
local cached: string? = nil
local cachedAt = -math.huge

-- The player's language: "en", "pt" or "es" (on the server, always "en").
function Lang.code(): string
	if RunService:IsServer() then
		return "en"
	end
	if cached and os.clock() - cachedAt < 1 then
		return cached
	end
	local code = "en"
	local player = Players.LocalPlayer
	local raw = player and player:GetAttribute("Settings")
	local chosen = 0
	if type(raw) == "string" then
		local ok, decoded = pcall(function()
			return game:GetService("HttpService"):JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" and type(decoded.language) == "number" then
			chosen = decoded.language
		end
	end
	if LANGS[chosen] then
		code = LANGS[chosen]
	else
		local ok, locale = pcall(function()
			return game:GetService("LocalizationService").RobloxLocaleId
		end)
		local id = if ok and type(locale) == "string" then string.lower(locale) else ""
		if string.sub(id, 1, 2) == "pt" then
			code = "pt"
		elseif string.sub(id, 1, 2) == "es" then
			code = "es"
		end
	end
	cached = code
	cachedAt = os.clock()
	return code
end

-- The text for `key` in the player's language (or `fallback`, or the key).
function Lang.t(key: string, fallback: string?): string
	local entry = S[key]
	if not entry then
		return fallback or key
	end
	local code = Lang.code()
	return (entry :: any)[code] or entry.en
end

-- Like Lang.t, and fills {name} blanks from `vars`.
function Lang.f(key: string, vars: { [string]: any }, fallback: string?): string
	local text = Lang.t(key, fallback)
	return (
		string.gsub(text, "{(%w+)}", function(name)
			local value = vars[name]
			return if value ~= nil then tostring(value) else "{" .. name .. "}"
		end)
	)
end

return Lang
