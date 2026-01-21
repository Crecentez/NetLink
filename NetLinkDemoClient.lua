-- NetLinkDemoClient.lua
-- v1.0.0
-- © 2025 Crecentez / Lunoxi Studios
-- Licensed under the MIT License. See LICENSE file.

local NetLink = require(game.ReplicatedStorage:WaitForChild("NetLink"))

NetLink.WaitTillLoaded()

-- Listen to server's reply
NetLink.Listen(nil, "TestEvent", function(_, message)
	print("Server replied:", message)
end)

-- Fire RemoteEvent
NetLink.FireServer("TestEvent", "Hello Server!")

-- Invoke RemoteFunction
local result = NetLink.InvokeServer("TestFunction", nil, 5)
print("TestFunction result:", result)

-- Async invoke example
NetLink.InvokeServerAsync("TestFunction", 3, 7)
	:andThen(function(res)
		print("Async result:", res)
	end)
	:catch(function(err)
		warn("Async failed:", err)
	end)
