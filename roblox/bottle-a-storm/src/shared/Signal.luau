-- Minimal signal for server-side events between services.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} :: { (...any) -> () } }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)
	local handlers = self._handlers
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
