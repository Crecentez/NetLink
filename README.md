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

---

## Installation

Place `Network.lua` in a shared location (e.g. `ReplicatedStorage.Modules.Network`).

Require it where needed:

```lua
local Network = require(ReplicatedStorage.Modules.Network)
```

---

## Lifecycle

The network has a strict lifecycle: 
1. `Network.Configure(...)`
2. `Network.Load()`
3. Listen / Fire / Invoke

`Load` must be called on the server before any client or server usage.

---

## Server Usage
### Configuration
```lua
Network.Configure({
    RemoteEvents = { "Damage", "Notify" },
    RemoteFunctions = { "GetStats" },
    DebugMode = true,
    UseMiddleware = true
})
```
### Loading
```lua
Network.Load()
```
### Listening
```lua
Network.Listen(self, "Damage", function(_, player, amount)
    print(player, amount)
end)
```
### Invoking
```lua
Network.OnInvoke(self, "GetStats", function()
    return Network.GetStats()
end)
```

---

## Client Usage
### Fire Event
```lua
Network.FireServer("Damage", 10)
```

### Invoke Function
```lua
local result = Network.InvokeServer("GetStats", 2)
```

### Async Invoke
```lua
Network.InvokeServerAsync("GetStats", 2)
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
Network.UseMiddleware(function(ctx)
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
Network.SetRateLimit("Damage", 5, 1)
```
Limits each player to 5 calls per second for the given remote.
This is intended for abuse reduction, not exploit prevention.

---

## Bindables

BindableEvents and BindableFunctions are server-internal tools.

They are useful for decoupling server systems without remotes.
They are created and bound via the same Network API but are not replicated.

---

## Stats
```lua
local stats = Network.GetStats()
```
Provides live counters for diagnostics and monitoring.

---

## Stability

Public API is stable as of v1.0.0
Internal implementation is not part of the API and may change

---

## License
MIT License © 2025 Crecentez / Lunoxi Studios
