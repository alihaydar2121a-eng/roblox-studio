--!nocheck
-- Unit tests for Roblox-independent game logic. Run: luau tests/run.luau
local T = require("./TestRunner")
local describe, eq, near, truthy = T.describe, T.expectEqual, T.expectNear, T.expectTrue

local GameConfig = require("../src/shared/Config/GameConfig")
local WeaponConfig = require("../src/shared/Config/WeaponConfig")
local CaptureLogic = require("../src/shared/Logic/CaptureLogic")
local TicketLogic = require("../src/shared/Logic/TicketLogic")
local WeaponLogic = require("../src/shared/Logic/WeaponLogic")
local TeamLogic = require("../src/shared/Logic/TeamLogic")
local RateLimiter = require("../src/shared/Util/RateLimiter")
local Validate = require("../src/shared/Util/Validate")

local cap = GameConfig.Capture
local A, B = "Alpha", "Bravo"

local function run(state, ca, cb, seconds, dt)
	dt = dt or 0.25
	local all = {}
	local t = 0
	while t < seconds - 1e-9 do
		local events
		state, events = CaptureLogic.step(state, A, B, ca, cb, dt, cap)
		for _, e in ipairs(events) do
			table.insert(all, e)
		end
		t += dt
	end
	return state, all
end

describe("CaptureLogic", function(it)
	it("captures a neutral point with one player in 1/rate seconds", function()
		local s, events = run(CaptureLogic.newState(), 1, 0, 1 / cap.RatePerSecond)
		eq(s.owner, A)
		near(s.control, 1)
		eq(#events, 1)
		eq(events[1].kind, "Captured")
		eq(events[1].team, A)
	end)

	it("does not capture early", function()
		local s = run(CaptureLogic.newState(), 1, 0, 1 / cap.RatePerSecond - 1)
		eq(s.owner, nil)
		truthy(s.control > 0 and s.control < 1)
		eq(s.capturingTeam, A)
	end)

	it("more capturers are faster, capped at MaxCapturers", function()
		local one = CaptureLogic.captureSpeed(1, cap)
		local two = CaptureLogic.captureSpeed(2, cap)
		local many = CaptureLogic.captureSpeed(50, cap)
		truthy(two > one)
		near(many, CaptureLogic.captureSpeed(cap.MaxCapturers, cap))
		eq(CaptureLogic.captureSpeed(0, cap), 0)
	end)

	it("freezes when contested", function()
		local s = run(CaptureLogic.newState(), 1, 0, 3)
		local before = s.control
		local s2, events = run(s, 2, 1, 5)
		near(s2.control, before)
		truthy(s2.contested)
		eq(#events, 0)
	end)

	it("enemy must neutralize before capturing", function()
		local s = run(CaptureLogic.newState(), 1, 0, 1 / cap.RatePerSecond) -- A owns
		local s2, events = run(s, 0, 1, 2 / cap.RatePerSecond)
		eq(#events, 2)
		eq(events[1].kind, "Neutralized")
		eq(events[1].team, B)
		eq(events[1].previousOwner, A)
		eq(events[2].kind, "Captured")
		eq(events[2].team, B)
		eq(s2.owner, B)
		near(s2.control, -1)
	end)

	it("unattended partial capture decays back to owner", function()
		local s = run(CaptureLogic.newState(), 1, 0, 1 / cap.RatePerSecond)
		s = run(s, 0, 1, 3) -- B pushes a little
		truthy(s.control < 1)
		s = run(s, 0, 0, 120)
		near(s.control, 1)
		eq(s.owner, A)
	end)

	it("unowned partial progress decays to neutral", function()
		local s = run(CaptureLogic.newState(), 0, 2, 3)
		truthy(s.control < 0)
		s = run(s, 0, 0, 120)
		near(s.control, 0)
		eq(s.owner, nil)
	end)

	it("owner standing on a full point produces no events", function()
		local s = run(CaptureLogic.newState(), 1, 0, 1 / cap.RatePerSecond)
		local s2, events = run(s, 3, 0, 10)
		eq(#events, 0)
		eq(s2.capturingTeam, nil)
		eq(s2.owner, A)
	end)
end)

describe("TicketLogic", function(it)
	local ids = { A, B }
	local cfg = GameConfig.Match
	it("no bleed without a majority", function()
		local r = TicketLogic.bleedRates({ [A] = 1, [B] = 1 }, ids, 3, cfg)
		eq(r[A], 0)
		eq(r[B], 0)
	end)
	it("minority side bleeds proportional to difference", function()
		local r = TicketLogic.bleedRates({ [A] = 2, [B] = 1 }, ids, 3, cfg)
		eq(r[A], 0)
		near(r[B], cfg.BleedPerPointPerSecond)
		local r2 = TicketLogic.bleedRates({ [B] = 3 }, ids, 3, cfg)
		near(r2[A], 3 * cfg.BleedPerPointPerSecond)
	end)
	it("resolves winners", function()
		eq(TicketLogic.resolveWinner({ [A] = 10, [B] = 0 }, ids, false), A)
		eq(TicketLogic.resolveWinner({ [A] = 0, [B] = 4 }, ids, false), B)
		eq(TicketLogic.resolveWinner({ [A] = 0, [B] = 0 }, ids, false), "Draw")
		eq(TicketLogic.resolveWinner({ [A] = 5, [B] = 5 }, ids, false), nil)
		eq(TicketLogic.resolveWinner({ [A] = 5, [B] = 5 }, ids, true), "Draw")
		eq(TicketLogic.resolveWinner({ [A] = 6, [B] = 5 }, ids, true), A)
	end)
end)

describe("WeaponLogic", function(it)
	local w = WeaponConfig.get("IR7")
	it("applies falloff", function()
		eq(WeaponLogic.damageAt(w, 10, false), w.Damage)
		eq(WeaponLogic.damageAt(w, 10000, false), w.MinDamage)
		local mid = WeaponLogic.damageAt(w, (w.FalloffStart + w.FalloffEnd) / 2, false)
		truthy(mid < w.Damage and mid > w.MinDamage)
	end)
	it("headshots multiply", function()
		eq(WeaponLogic.damageAt(w, 10, true), math.floor(w.Damage * w.HeadMultiplier + 0.5))
	end)
	it("enforces cadence with tolerance", function()
		local interval = WeaponLogic.fireInterval(w)
		near(interval, 0.1)
		truthy(not WeaponLogic.canFire(1, 1 + interval * 0.5, w, 0.75))
		truthy(WeaponLogic.canFire(1, 1 + interval * 0.8, w, 0.75))
	end)
	it("reloads from reserve", function()
		local mag, reserve = WeaponLogic.reloadResult(5, 150, 30)
		eq(mag, 30)
		eq(reserve, 125)
		mag, reserve = WeaponLogic.reloadResult(5, 10, 30)
		eq(mag, 15)
		eq(reserve, 0)
		mag, reserve = WeaponLogic.reloadResult(30, 10, 30)
		eq(mag, 30)
		eq(reserve, 10)
	end)
	it("time to kill is sane (4-6 body shots up close)", function()
		local shots = math.ceil(100 / WeaponLogic.damageAt(w, 10, false))
		truthy(shots >= 4 and shots <= 6, "shots=" .. shots)
	end)
end)

describe("TeamLogic", function(it)
	it("blocks stacking beyond max difference", function()
		truthy(TeamLogic.canJoin({ [A] = 3, [B] = 3 }, A, 1))
		truthy(not TeamLogic.canJoin({ [A] = 4, [B] = 3 }, A, 1))
		truthy(TeamLogic.canJoin({ [A] = 4, [B] = 3 }, B, 1))
		truthy(not TeamLogic.canJoin({ [A] = 0 }, "Nope", 1))
	end)
	it("auto picks the smaller team, tie -> first", function()
		eq(TeamLogic.pickAuto({ [A] = 2, [B] = 1 }, { A, B }), B)
		eq(TeamLogic.pickAuto({ [A] = 1, [B] = 1 }, { A, B }), A)
	end)
end)

describe("RateLimiter", function(it)
	it("allows a burst then refills over time", function()
		local now = 0
		local limiter = RateLimiter.new(3, 1, function()
			return now
		end)
		truthy(limiter:allow(1))
		truthy(limiter:allow(1))
		truthy(limiter:allow(1))
		truthy(not limiter:allow(1))
		truthy(limiter:allow(2), "keys are independent")
		now = 1
		truthy(limiter:allow(1))
		truthy(not limiter:allow(1))
		now = 100
		for _ = 1, 3 do
			truthy(limiter:allow(1))
		end
		truthy(not limiter:allow(1), "capacity caps refill")
	end)
end)

describe("Validate", function(it)
	it("rejects non-finite numbers", function()
		truthy(Validate.finiteNumber(1.5))
		truthy(not Validate.finiteNumber(0 / 0))
		truthy(not Validate.finiteNumber(math.huge))
		truthy(not Validate.finiteNumber("1"))
	end)
	it("checks strings and enums", function()
		truthy(Validate.shortString("Alpha"))
		truthy(not Validate.shortString(""))
		truthy(not Validate.shortString(string.rep("x", 100)))
		truthy(Validate.oneOf("B", { "A", "B" }))
		truthy(not Validate.oneOf("C", { "A", "B" }))
	end)
	it("rejects non-Vector3 values", function()
		truthy(not Validate.vector3({ X = 1, Y = 2, Z = 3 }))
		truthy(not Validate.unitVector3(nil))
	end)
end)

describe("Config sanity", function(it)
	it("has exactly two teams with unique ids", function()
		eq(#GameConfig.Teams, 2)
		truthy(GameConfig.Teams[1].Id ~= GameConfig.Teams[2].Id)
	end)
	it("default weapon exists", function()
		truthy(WeaponConfig.get(WeaponConfig.DefaultWeapon) ~= nil)
	end)
end)

if not T.finish() then
	error("tests failed")
end
