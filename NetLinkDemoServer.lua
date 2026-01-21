-- NetLinkDemoServer.lua
-- v1.0.0
-- © 2025 Crecentez / Lunoxi Studios
-- Licensed under the MIT License. See LICENSE file.

local NetLink = require(game.ReplicatedStorage:WaitForChild("NetLink"))

-- Configure NetLink
NetLink.Configure({
	RemoteEvents = {"TestEvent"},
	RemoteFunctions = {"TestFunction"},
	BindableEvents = {"TestBindableEvent"},
	BindableFunctions = {"TestBindableFunction"},
	DebugMode = true,
	UseMiddleware = true,
})

NetLink.Load()

-- Example Middleware: block "BlockedPlayer"
NetLink.UseMiddleware(function(ctx)
	if ctx.Player.Name == "BlockedPlayer" then
		warn("BlockedPlayer tried to fire:", ctx.Name)
		return false
	end
	return true
end)

-- Rate limit "TestEvent" to 2 calls per 5 seconds
NetLink.SetRateLimit("TestEvent", 2, 5)

-- Listen for RemoteEvent
NetLink.Listen(nil, "TestEvent", function(_, player, message)
	print(player.Name, "sent TestEvent:", message)
	-- Reply back to the client
	NetLink.FireClient(player, "TestEvent", "Received: " .. message)
end)

-- Listen for RemoteFunction
NetLink.OnInvoke(nil, "TestFunction", function(_, player, number)
	print(player.Name, "invoked TestFunction with", number)
	return number * 2
end)

-- Bindable Event
NetLink.BindEvent(nil, "TestBindableEvent", function(_, msg)
	print("BindableEvent fired with:", msg)
end)

-- Bindable Function
NetLink.BindFunction(nil, "TestBindableFunction", function(_, num)
	print("BindableFunction invoked with:", num)
	return num + 10
end)

-- Fire a Bindable Event after 5 seconds
task.delay(5, function()
	local folder = game.ServerScriptService:WaitForChild("BindableEvents")
	folder.TestBindableEvent:Fire("Hello from server!")
end)
