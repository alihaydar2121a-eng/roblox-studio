--[[
	Signal
	Minimal synchronous signal for decoupling server/client modules.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self.handlers
	table.insert(handlers, fn)
	return {
		Disconnect = function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect while firing.
	for _, fn in ipairs(table.clone(self.handlers)) do
		fn(...)
	end
end

return Signal
