-- NetLink.lua
-- v1.0.0
-- © 2025 Crecentez / Lunoxi Studios
-- Licensed under the MIT License. See LICENSE file.

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

export type StatsType = {
	RemoteRecieves: {[string]: number},
	PlayerRecieves: {[Player]: number},
	MiddlewareBlocks: number,
	ActiveConnections: number,
	TotalRemotes: number
}

-- Module
local NetLink = {}
NetLink.__index = NetLink

local Middleware: { (ctx: {
	player: Player,
	Name: string,
	Args: {any}
}) -> boolean} = {}

-- Constants
local FOLDERS = {
	RemoteEvents = "RemoteEvents",
	RemoteFunctions = "RemoteFunctions",
	BindableEvents = "BindableEvents",
	BindableFunctions = "BindableFunctions"
}

local RemoteEvents = { "Example Remote Event" }
local RemoteFunctions = { "Example Remote Function" }
local BindableEvents = { "Example Bindable Event" }
local BindableFunctions = { "Example Bindable Function" }

-- State
local Loaded: BoolValue?
local Configured = false
local DebugMode = false
local UserMiddleware = false
local ConnectionsByOwner: {[any]: {RBXScriptConnection}} = {}

local RateLimits: {[string]: {Limit: number, Window: number}} = {}
local RateBuckets: {[Player]: {[string]: {Count: number, ResetAt: number}}} = {}

local NetLinkStats = {
	RemoteRecieves = {},
	PlayerRecieves = {},
	MiddlewareBlocks = 0,
}

if RunService:IsServer() then
	if Loaded == nil then
		Loaded = Instance.new("BoolValue")
		Loaded.Name = "Loaded"
		Loaded.Parent = script
	end
else
	Loaded = script:FindFirstChild("Loaded")
end

-- Internal helpers
local function assertLoaded()
	assert(Loaded ~= nil and Loaded.Value, "NetLink.Load() must be called on the server before use")
end

local function getFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function getRemote(folderName: string, name: string, className: string)
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	assert(folder, folderName .. " folder missing")

	local remote = folder:FindFirstChild(name)
	assert(remote and remote:IsA(className), (`{name} is not a valid {className}`))

	return remote
end

local function trackConnection(owner: any, conn: RBXScriptConnection)
	if not owner then return end
	ConnectionsByOwner[owner] = ConnectionsByOwner[owner] or {}
	table.insert(ConnectionsByOwner[owner], conn)
end

local function assert(condition: boolean, msg: string)
	if condition == false or condition == nil then
		error("[NetLink] \t::\t "..msg)
	end
end

local function log(msg: string, doWarning: boolean?)
	if doWarning then
		warn("[NetLink] \t::\t "..msg)
		return
	end
	if DebugMode then
		print("[NetLink] \t::\t "..msg)
	end
end

local function ValidateMiddleware(ctx: {Player: Player, Name: string, Args: {any}}): boolean
	if not UserMiddleware then return true end
	for _, mw in Middleware do
		if mw(ctx) == false then
			NetLinkStats.MiddlewareBlocks += 1
			log("Failed middleware", false)
			return false
		end
	end
	return true
end

local function AddRemoteRecieves(name: string)
	if NetLinkStats.RemoteRecieves[name] then
		NetLinkStats.RemoteRecieves[name] += 1
	else
		NetLinkStats.RemoteRecieves[name] = 1
	end
end

local function AddPlayerRecieves(player: Player)
	if NetLinkStats.PlayerRecieves[player.Name] then
		NetLinkStats.PlayerRecieves[player.Name] += 1
	else
		NetLinkStats.PlayerRecieves[player.Name] = 1
	end
end

-- Promise

--[[
	Creates a new Promise.

	@param executor (resolve, reject) -> ()
]]
local Promise = {}
Promise.__index = Promise

function Promise.new(executor)
	local self = setmetatable({}, Promise)

	self._state = "Pending"
	self._value = nil
	self._success = {}
	self._failure = {}

	local function resolve(value)
		if self._state ~= "Pending" then return end
		self._state = "Fulfilled"
		self._value = value
		for _, cb in self._success do
			task.spawn(cb, value)
		end
	end

	local function reject(err)
		if self._state ~= "Pending" then return end
		self._state = "Rejected"
		self._value = err
		for _, cb in self._failure do
			task.spawn(cb, err)
		end
	end

	task.defer(executor, resolve, reject)
	return self
end

--[[
	Registers a success callback.

	@param method (value:any) -> ()
]]
function Promise:andThen(method)
	if self._state == "Fulfilled" then
		task.spawn(method, self._value)
	elseif self._state == "Pending" then
		table.insert(self._success, method)
	end
	return self
end

--[[
	Registers a failure callback.

	@param method (err:any) -> ()
]]
function Promise:catch(method)
	if self._state == "Rejected" then
		task.spawn(method, self._value)
	elseif self._state == "Pending" then
		table.insert(self._failure, method)
	end
	return self
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

--[[
	Configures remotes, bindables, and runtime options.
	Must be called before Load.

	@param t.RemoteEvents {string}? 
	@param t.RemoteFunctions {string}?
	@param t.BindableEvents {string}?
	@param t.BindableFunctions {string}?
	@param t.DebugMode boolean?
	@param t.UseMiddleware boolean?
]]
function NetLink.Configure(t: {RemoteEvents: {string}?, RemoteFunctions: {string}?, BindableEvents: {string}?, BindableFunctions: {string}?, DebugMode: boolean?, UseMiddleware: boolean?})
	assert(RunService:IsServer(), "SetRateLimit is server-only")
	RemoteEvents = t.RemoteEvents or RemoteEvents
	RemoteFunctions = t.RemoteFunctions or RemoteFunctions
	BindableEvents = t.BindableEvents or BindableEvents
	BindableFunctions = t.BindableFunctions or BindableFunctions
	DebugMode = t.DebugMode or false
	UserMiddleware = t.UseMiddleware or false
	Configured = true
	log("Configured")
end

--[[
	Creates all configured remotes and bindables.
	Enables middleware and rate limiting if configured.
]]
function NetLink.Load()
	assert(RunService:IsServer(), "SetRateLimit is server-only")

	if Loaded == nil then
		Loaded = Instance.new("BoolValue")
		Loaded.Name = "Loaded"
		Loaded.Parent = script
	end

	local remoteFolder = getFolder(ReplicatedStorage, FOLDERS.RemoteEvents)
	local functionFolder = getFolder(ReplicatedStorage, FOLDERS.RemoteFunctions)

	local bindableEventFolder = getFolder(ServerScriptService, FOLDERS.BindableEvents)
	local bindableFunctionFolder = getFolder(ServerScriptService, FOLDERS.BindableFunctions)

	for _, name in ipairs(RemoteEvents) do
		if not remoteFolder:FindFirstChild(name) then
			Instance.new("RemoteEvent", remoteFolder).Name = name
		end
	end

	for _, name in ipairs(RemoteFunctions) do
		if not functionFolder:FindFirstChild(name) then
			Instance.new("RemoteFunction", functionFolder).Name = name
		end
	end

	for _, name in ipairs(BindableEvents) do
		if not bindableEventFolder:FindFirstChild(name) then
			Instance.new("BindableEvent", bindableEventFolder).Name = name
		end
	end

	for _, name in ipairs(BindableFunctions) do
		if not bindableFunctionFolder:FindFirstChild(name) then
			Instance.new("BindableFunction", bindableFunctionFolder).Name = name
		end
	end

	if UserMiddleware then
		NetLink.UseMiddleware(function(ctx)
			local rule = RateLimits[ctx.Name]
			if not rule then
				return true
			end

			local player = ctx.Player
			local now = os.clock()

			RateBuckets[player] = RateBuckets[player] or {}
			local bucket = RateBuckets[player][ctx.Name]

			if not bucket or now >= bucket.ResetAt then
				bucket = {
					Count = 0,
					ResetAt = now + rule.Window
				}
				RateBuckets[player][ctx.Name] = bucket
			end

			bucket.Count += 1

			if bucket.Count > rule.Limit then
				log(`Rate limited: {ctx.Name} from {player.Name}`)
				return false
			end

			return true
		end)

		game:GetService("Players").PlayerRemoving:Connect(function(player)
			RateBuckets[player] = nil
			NetLink.DisconnectAll(player)
		end)
	end

	Loaded.Value = true
	log("Loaded")
end

--[[
	Registers a middleware callback.

	Middleware is validation-only.
	Return false to block execution.
	Failures are silent unless DebugMode is enabled.

	@param method (ctx:{Player:Player, Name:string, Args:{any}}) -> boolean
]]
function NetLink.UseMiddleware(method: (ctx: {
	Player: Player,
	Name: string,
	Args: {any}
	}) -> boolean)
	assert(RunService:IsServer(), "SetRateLimit is server-only")
	if not Middleware then
		log("Middleware is disabled! Enable in config.", true)
	end
	table.insert(Middleware, method)
	log("Middleware Added")
end

--[[
	Blocks until the network has finished loading.
]]
function NetLink.WaitTillLoaded()
	repeat task.wait() until script:FindFirstChild("Loaded") and script["Loaded"].Value == true
end

--[[
	Returns live network statistics.
	Intended for diagnostics and monitoring.

	@return StatsType
]]
function NetLink.GetStats(): StatsType
	local s: StatsType = table.clone(NetLinkStats)
	s.TotalRemotes = 0
	local eventFolder = getFolder(ReplicatedStorage, FOLDERS.RemoteEvents)
	local functionFolder = getFolder(ReplicatedStorage, FOLDERS.RemoteFunctions)
	if eventFolder then
		s.TotalRemotes += #eventFolder:GetChildren()
	end
	if functionFolder then
		s.TotalRemotes += #functionFolder:GetChildren()
	end
	s.ActiveConnections = #ConnectionsByOwner or 0
	return s
end

--[[
	Sets a per-player rate limit for a remote.

	@param remoteName string
	@param limit number
	@param window number -- seconds
]]
function NetLink.SetRateLimit(remoteName: string, limit: number, window: number)
	assert(RunService:IsServer(), "SetRateLimit is server-only")
	assert(limit > 0 and window > 0, "Invalid rate limit values")
	RateLimits[remoteName] = {
		Limit = limit,
		Window = window
	}
	log(`Rate limit set for {remoteName}: {limit}/{window}s`)
end

--[[
	Disconnects all tracked connections for an owner.

	@param owner any
]]
function NetLink.DisconnectAll(owner: any)
	local list = ConnectionsByOwner[owner]
	if not list then return end
	for _, conn in ipairs(list) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	ConnectionsByOwner[owner] = nil
end

--[[
	Listens for a RemoteEvent.

	@param owner any -- used for connection ownership
	@param eventName string
	@param method (owner:any, player:Player, ...any) -> ()
]]
function NetLink.Listen(owner: any, eventName: string, method)
	assertLoaded()
	assert(typeof(method) == "function", "method must be a function")

	local remote = getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent")

	local conn
	if RunService:IsServer() then
		conn = remote.OnServerEvent:Connect(function(player, ...)
			AddRemoteRecieves(eventName)
			AddPlayerRecieves(player)
			if not ValidateMiddleware{Player = player, Name = eventName, Args = {...}} then return end
			method(owner, player, ...)
		end)
	else
		conn = remote.OnClientEvent:Connect(function(...)
			AddRemoteRecieves(eventName)
			AddPlayerRecieves(game.Players.LocalPlayer)
			method(owner, ...)
		end)
	end

	trackConnection(owner, conn)
	return conn
end

--[[
	Listens for a RemoteFunction invoke.

	@param owner any
	@param functionName string
	@param method (owner:any, player:Player, ...any) -> any
]]
function NetLink.OnInvoke(owner: any, functionName: string, method)
	assertLoaded()
	assert(typeof(method) == "function", "method must be a function")

	local remote = getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction")

	if RunService:IsServer() then
		remote.OnServerInvoke = function(player, ...)
			AddRemoteRecieves(functionName)
			AddPlayerRecieves(player)
			if not ValidateMiddleware{Player = player, Name = functionName, Args = {...}} then return end
			return method(owner, player, ...)
		end
	else
		remote.OnClientInvoke = function(...)
			AddRemoteRecieves(functionName)
			AddPlayerRecieves(game.Players.LocalPlayer)
			return method(owner, ...)
		end
	end
end

--[[
	Listens for a RemoteEvent once.

	@param owner any
	@param eventName string
	@param method (owner:any, player:Player, ...any) -> ()
]]
function NetLink.ListenOnce(owner: any, eventName: string, method)
	assertLoaded()
	assert(typeof(method) == "function", "method must be a function")

	local remote = getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent")
	local conn
	if RunService:IsServer() then
		conn = remote.OnServerEvent:Once(function(player, ...)
			AddRemoteRecieves(eventName)
			AddPlayerRecieves(player)
			if not ValidateMiddleware{Player = player, Name = eventName, Args = {...}} then return end
			method(owner, player, ...)
		end)
	else
		conn = remote.OnClientEvent:Once(function(...)
			AddRemoteRecieves(eventName)
			AddPlayerRecieves(game.Players.LocalPlayer)
			method(owner, ...)
		end)
	end

	trackConnection(owner, conn)
	return conn
end

--[[
	Handles a RemoteFunction invoke once.

	@param owner any
	@param functionName string
	@param method (owner:any, player:Player, ...any) -> any
]]
function NetLink.OnInvokeOnce(owner: any, functionName: string, method)
	assertLoaded()
	assert(typeof(method) == "function", "method must be a function")

	local remote: RemoteFunction = getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction")
	if RunService:IsServer() then
		remote.OnServerInvoke = function(player, ...)
			AddRemoteRecieves(functionName)
			AddPlayerRecieves(player)
			if not ValidateMiddleware{Player = player, Name = functionName, Args = {...}} then return end
			remote.OnServerInvoke = nil
			return method(owner, player, ...)
		end
	else
		remote.OnClientInvoke = function(...)
			AddRemoteRecieves(functionName)
			AddPlayerRecieves(game.Players.LocalPlayer)
			remote.OnClientInvoke = nil
			return method(owner, ...)
		end
	end
end

--[[
	Binds to a server-only BindableEvent.

	@param owner any
	@param name string
	@param method (owner:any, ...any) -> ()
]]
function NetLink.BindEvent(owner: any, name: string, method)
	assert(RunService:IsServer(), "BindableEvents are server-only")
	assert(typeof(method) == "function", "method must be a function")

	local folder = ServerScriptService[FOLDERS.BindableEvents]
	local bindable = folder:FindFirstChild(name)
	assert(bindable, "BindableEvent not found: " .. name)

	local conn = bindable.Event:Connect(function(...)
		method(owner, ...)
	end)

	trackConnection(owner, conn)
	return conn
end

--[[
	Binds to a server-only BindableFunction.

	@param owner any
	@param name string
	@param method (owner:any, ...any) -> any
]]
function NetLink.BindFunction(owner: any, name: string, method)
	assert(RunService:IsServer(), "BindableFunctions are server-only")
	assert(typeof(method) == "function", "method must be a function")

	local folder = ServerScriptService[FOLDERS.BindableFunctions]
	local bindable = folder:FindFirstChild(name)
	if not bindable then
		error("BindableFunction not found: " .. name)
	end

	bindable.OnInvoke = function(...)
		return method(owner, ...)
	end
end

--[[
	Fires a RemoteEvent to a single client.

	@param player Player
	@param eventName string
]]
function NetLink.FireClient(player: Player, eventName: string, ...)
	assert(RunService:IsServer(), "FireClient can only be called on server")
	assert(player:IsA("Player"), "First argument must be Player")
	getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent"):FireClient(player, ...)
end

--[[
	Fires a RemoteEvent to all clients.

	@param eventName string
]]
function NetLink.FireAll(eventName: string, ...)
	assert(RunService:IsServer(), "FireAll is server-only")
	getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent"):FireAllClients(...)
end

--[[
	Fires a RemoteEvent to all clients except one.

	@param excludedPlayer Player
	@param eventName string
]]
function NetLink.FireExcept(excludedPlayer: Player, eventName: string, ...)
	assert(RunService:IsServer(), "FireClient can only be called on server")
	assert(excludedPlayer:IsA("Player"), "First argument must be Player")
	local remote = getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent")
	for i, plr: Player in pairs(Players:GetPlayers()) do
		if plr == excludedPlayer then continue end
		remote:FireClient(plr, ...)
	end
end

--[[
	Fires a RemoteEvent to a list of players.

	@param players {Player}
	@param eventName string
]]
function NetLink.FireBatch(players: {Player}, eventName: string, ...)
	assert(RunService:IsServer(), "FireClient can only be called on server")
	assert(typeof(players) == "table", "FireBatch expects a table of Players")
	local remote = getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent")
	for i, plr: Player in ipairs(players) do
		assert(typeof(plr) == "Instance" and plr:IsA("Player"), `FireBatch expected Player at index {i}`)
		remote:FireClient(plr, ...)
	end
end

--[[
	Invokes a RemoteFunction on a client.
	Returns nil if timed out.

	@param functionName string
	@param timeout number?
	@param player Player
]]
function NetLink.InvokeClient(functionName: string, timeout: number?, player: Player, ...)
	assert(RunService:IsServer(), "InvokeClient can only be called on server")
	assert(player:IsA("Player"), "First argument must be Player")
	if timeout then
		local args = table.pack(...)
		local finished = false
		local result

		task.spawn(function()
			result = getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction"):InvokeClient(table.unpack(args, 1, args.n))
			finished = true
		end)

		local start = os.clock()
		while not finished do
			if os.clock() - start >= timeout then
				return nil
			end
			task.wait()
		end
		return result
	else
		return getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction"):InvokeClient(player, ...)
	end
end

--[[
	Invokes a RemoteFunction on a client asynchronously.

	@param functionName string
	@param timeout number
	@return Promise
]]
function NetLink.InvokeClientAsync(functionName: string, timeout: number, ...)
	local args = table.pack(...)

	return Promise.new(function(resolve, reject)
		local finished = false

		task.spawn(function()
			local ok, result = pcall(NetLink.InvokeClient, functionName, nil, table.unpack(args, 1, args.n))

			if finished then return end
			finished = true

			if ok then
				resolve(result)
			else
				reject(result)
			end
		end)

		task.delay(timeout, function()
			if finished then return end
			finished = true
			reject("InvokeClientAsync timed out after "..timeout.."s")
		end)
	end)
end

--[[
	Fires a RemoteEvent to the server.
]]
function NetLink.FireServer(eventName: string, ...)
	assert(RunService:IsClient(), "FireServer can only be called on client")
	getRemote(FOLDERS.RemoteEvents, eventName, "RemoteEvent"):FireServer(...)
end

--[[
	Invokes a RemoteFunction on the server.
	Returns nil if timed out.

	@param functionName string
	@param timeout number?
]]
function NetLink.InvokeServer(functionName: string, timeout: number?, ...)
	assert(RunService:IsClient(), "InvokeServerAsync can only be called on client")
	if timeout then
		local args = table.pack(...)
		local finished = false
		local result

		task.spawn(function()
			result = getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction"):InvokeServer(table.unpack(args, 1, args.n))
			finished = true
		end)

		local start = os.clock()
		while not finished do
			if os.clock() - start >= timeout then
				return nil
			end
			task.wait()
		end
		return result
	else
		return getRemote(FOLDERS.RemoteFunctions, functionName, "RemoteFunction"):InvokeServer(...)
	end
end

--[[
	Invokes a RemoteFunction on the server asynchronously.

	@param functionName string
	@param timeout number
	@return Promise
]]
function NetLink.InvokeServerAsync(functionName: string, timeout: number, ...)
	local args = table.pack(...)

	return Promise.new(function(resolve, reject)
		local finished = false

		task.spawn(function()
			local ok, result = pcall(NetLink.InvokeServer, functionName, nil, table.unpack(args, 1, args.n))

			if finished then return end
			finished = true

			if ok then
				resolve(result)
			else
				reject(result)
			end
		end)

		task.delay(timeout, function()
			if finished then return end
			finished = true
			reject("InvokeServerAsync timed out after "..timeout.."s")
		end)
	end)
end

return NetLink
