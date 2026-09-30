--[[
	GameConfig
	Central tuning values for OPERATION IRONFRONT. Pure data: no Roblox API
	access, so it can be required by server, client and offline tests.
]]

local GameConfig = {}

GameConfig.MaxPlayers = 24 -- stable target; systems avoid per-player O(n^2) work so 80 remains viable

GameConfig.Teams = {
	{
		Id = "Alpha",
		Name = "Ashford Coalition",
		ShortName = "ASH",
		TeamColorName = "Moss", -- BrickColor name used for the Roblox Team object
		UiColor = { 176, 196, 108 }, -- light olive, distinct luminance from Bravo
		Uniform = {
			Torso = { 92, 101, 62 },
			Legs = { 74, 80, 52 },
			Arms = { 92, 101, 62 },
			Helmet = { 70, 78, 46 },
			Vest = { 128, 118, 84 },
			Band = { 214, 190, 90 },
		},
	},
	{
		Id = "Bravo",
		Name = "Varn Directorate",
		ShortName = "VRN",
		TeamColorName = "Steel blue",
		UiColor = { 96, 150, 220 },
		Uniform = {
			Torso = { 58, 70, 92 },
			Legs = { 46, 52, 66 },
			Arms = { 58, 70, 92 },
			Helmet = { 40, 46, 58 },
			Vest = { 88, 96, 104 },
			Band = { 120, 200, 230 },
		},
	},
}

GameConfig.TeamBalanceMaxDifference = 1

GameConfig.Match = {
	DurationSeconds = 20 * 60,
	StartingTickets = 300,
	TicketLossPerDeath = 1,
	-- Losing-side bleed per second for every objective the enemy holds beyond yours,
	-- applied only while the enemy holds a majority of objectives.
	BleedPerPointPerSecond = 0.5,
	IntermissionSeconds = 15,
}

GameConfig.Respawn = {
	DelaySeconds = 6,
	SpawnProtectionSeconds = 3,
}

GameConfig.Capture = {
	TickSeconds = 0.25,
	-- Fraction of the full control range (-1..1 is 2.0) gained per second by one capturer.
	-- Neutral -> captured with 1 player = 1 / RatePerSecond seconds.
	RatePerSecond = 1 / 12,
	CapturerBonus = 0.5, -- each extra capturer adds 50% speed...
	MaxCapturers = 4, -- ...up to this many counted
	IdleRecoverPerSecond = 1 / 30, -- unattended points drift back to their owner (or neutral)
	HeightTolerance = 24,
}

GameConfig.Score = {
	Kill = 100,
	HeadshotBonus = 25,
	Capture = 200,
	Neutralize = 100,
}

GameConfig.Combat = {
	MaxOriginOffset = 10, -- studs between the claimed shot origin and the server's view of the head
	FireIntervalTolerance = 0.75, -- accept shots arriving at >= 75% of the weapon interval (network jitter)
	KillCreditWindow = 12, -- seconds a damager keeps kill credit
}

return GameConfig
