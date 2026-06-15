# NetLink

A structured networking module for Roblox that simplifies RemoteEvents, RemoteFunctions, middleware, and rate limiting.

Designed for intermediate Roblox developers to handle client-server communication reliably, removing the need to manually set up and manage remote events, functions, and middleware.

---

## Features

- Unified API for events and functions
- Optional middleware pipeline
- Built-in per-player rate limiting
- Async invoke support via internal Promise
- Connection ownership and cleanup
- Server-internal BindableEvent / BindableFunction support
- Unreliable events
- Runtime event creation

---

## Latest Changes (V 1.1.0)

 - Added unreliable event support
 - Added runtime event/function creation
 - Added support for wally

---

## Installation

Place `NetLink.lua` in a shared location (e.g. `ReplicatedStorage.Modules.NetLink`).

Require it where needed:

```lua
local NetLink = require(ReplicatedStorage.Modules.NetLink)
```

---

## Lifecycle

The NetLink has a strict lifecycle: 
1. `NetLink.Configure(...)`
2. `NetLink.Load()`
3. Listen / Fire / Invoke

`Load` must be called on the server before any client or server usage.

---

## Server Usage
### Configuration
```lua
NetLink.Configure({
    RemoteEvents = { "Damage", "Notify" },
    RemoteFunctions = { "GetStats" },
    DebugMode = true,
    UseMiddleware = true
})
```
### Loading
```lua
NetLink.Load()
```
### Listening
```lua
NetLink.Listen(self, "Damage", function(_, player, amount)
    print(player, amount)
end)
NetLink.ListenUnreliable(self, "Fire", function(_, player, direction)
    print(`{player.Name} is trying to fire at direction {direction}`)
end)
```
### Invoking
```lua
NetLink.OnInvoke(self, "GetStats", function()
    return NetLink.GetStats()
end)
```

---

## Client Usage
### Fire Event
```lua
NetLink.FireServer("Damage", 10)
NetLink.FireServerUnreliable("Fire", Vector3.new(1, 1, 1))
```

### Invoke Function
```lua
local result = NetLink.InvokeServer("GetStats", 2)
```

### Async Invoke
```lua
NetLink.InvokeServerAsync("GetStats", 2)
    :andThen(function(result)
        print(result)
    end)
    :catch(function(err)
        warn(err)
    end)
```

---

## Middleware

Middleware is validation-only.
 - Receives `{ Player, Name, Args }`
 - Return `false` to block execution
 - Failures are silent unless `DebugMode` is enabled
 - Must be enabled in configuration
```lua
NetLink.UseMiddleware(function(ctx)
    if ctx.Name == "Damage" and ctx.Args[1] > 100 then
        return false
    end
    return true
end)
```

---

## Rate Limiting

Rate limiting is server-side only.
```lua
NetLink.SetRateLimit("Damage", 5, 1)
```
Limits each player to 5 calls per second for the given remote.
This is intended for abuse reduction, not exploit prevention.

---

## Bindables

BindableEvents and BindableFunctions are server-internal tools.

They are useful for decoupling server systems without remotes.
They are created and bound via the same NetLink API but are not replicated.

---

## Stats
```lua
local stats = NetLink.GetStats()
```
Provides live counters for diagnostics and monitoring.

---

## Stability

Public API is stable as of v1.1.0
Internal implementation is not part of the API and may change

---

## License
MIT License © 2025 Crecentez / Lunoxi Studios