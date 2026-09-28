--!strict
-- The ⚙️ Settings menu: every option, its kind and its default. Choices are
-- saved with your profile (SettingsService) and read on your screen through
-- the client's Settings controller.

export type Setting = {
	key: string,
	name: string,
	hint: string,
	kind: "toggle" | "level",
	default: boolean | number,
	levels: { number }?, -- for "level": the steps you click through
	labels: { [number]: string }?, -- for "level": names for the steps (instead of %)
	mouseOnly: boolean?, -- only shown with a mouse and keyboard
	touchOnly: boolean?, -- only shown on phones and tablets
}

local SettingsData = {}

SettingsData.List = {
	{
		key = "language",
		name = "🌍 Language",
		hint = "Auto uses your Roblox language. Some text changes after you rejoin.",
		kind = "level",
		default = 0,
		levels = { 0, 1, 2, 3 },
		labels = { [0] = "Auto", [1] = "English", [2] = "Português", [3] = "Español" },
	},
	{
		key = "cameraLock",
		name = "🖱️ Camera follows the mouse",
		hint = "Off: hold right-click to turn the camera, like normal Roblox.",
		kind = "toggle",
		default = true,
		mouseOnly = true,
	},
	{
		key = "shoulder",
		name = "📷 Over-the-shoulder view",
		hint = "The camera sits a little to your right so you can aim past yourself.",
		kind = "toggle",
		default = true,
		mouseOnly = true,
	},
	{
		key = "phoneButtons",
		name = "📱 Big fight buttons",
		hint = "Big ⚔️ Use and 🎒 Next item buttons next to the jump button.",
		kind = "toggle",
		default = true,
		touchOnly = true,
	},
	{
		key = "music",
		name = "🎵 Music",
		hint = "Songs in the lobby and during matches.",
		kind = "level",
		default = 0.5,
		levels = { 0, 0.25, 0.5, 0.75, 1 },
	},
	{
		key = "sfx",
		name = "🔊 Sound effects",
		hint = "How loud hits, pops and chimes are.",
		kind = "level",
		default = 1,
		levels = { 0, 0.25, 0.5, 0.75, 1 },
	},
	{
		key = "ambient",
		name = "🕊️ Birds, balloons and floating islets",
		hint = "Little extras in the sky (only on your screen).",
		kind = "toggle",
		default = true,
	},
	{
		key = "quietMessages",
		name = "🔕 Fewer pop-up messages",
		hint = "News for everyone goes to 📜 Messages (📋 Menu) instead of popping up. Warnings still pop up.",
		kind = "toggle",
		default = false,
	},
	{
		key = "lowDetail",
		name = "⚡ Faster mode (less detail)",
		hint = "Hides flowers, bushes and little decorations so the game runs smoother on slow devices.",
		kind = "toggle",
		default = false,
	},
	{
		key = "damageNumbers",
		name = "💥 Damage numbers",
		hint = "Numbers pop up when you hit someone.",
		kind = "toggle",
		default = true,
	},
	{
		key = "killFeed",
		name = "📰 Kill feed",
		hint = "Knockouts and broken beds on the right side of the screen.",
		kind = "toggle",
		default = true,
	},
	{
		key = "effects",
		name = "✨ Fancy effects",
		hint = "Glow, sun rays and sparkly animations. Turn off if your game is slow.",
		kind = "toggle",
		default = true,
	},
	{
		key = "taunts",
		name = "💬 Other players' taunts",
		hint = "Speech bubbles over other players' heads.",
		kind = "toggle",
		default = true,
	},
	{
		key = "othersPets",
		name = "🐾 Show other players' pets",
		hint = "Your own pet always shows.",
		kind = "toggle",
		default = true,
	},
} :: { Setting }

function SettingsData.find(key: string): Setting?
	for _, setting in SettingsData.List do
		if setting.key == key then
			return setting
		end
	end
	return nil
end

-- Whether `value` is allowed for this setting.
function SettingsData.valid(setting: Setting, value: any): boolean
	if setting.kind == "toggle" then
		return type(value) == "boolean"
	end
	return type(value) == "number" and table.find(setting.levels or {}, value) ~= nil
end

return SettingsData
