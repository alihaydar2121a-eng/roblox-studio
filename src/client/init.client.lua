--[[
	OPERATION IRONFRONT — client bootstrap.
	Controllers are started in dependency order; each owns one concern.
]]

local EffectsController = require(script.Controllers.EffectsController)
local WeaponController = require(script.Controllers.WeaponController)
local HudController = require(script.Controllers.HudController)
local ObjectiveMarkers = require(script.Controllers.ObjectiveMarkers)
local TeamSelectController = require(script.Controllers.TeamSelectController)

EffectsController.start()
WeaponController.start()
TeamSelectController.start()
HudController.start()
ObjectiveMarkers.start()
