-- resources/hardcap/hardcap.lua
local maxClients = GetConvarInt("sv_maxclients", 30)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local numPlayers = GetNumPlayerIndices()
    
    if numPlayers >= maxClients then
        setKickReason('Server is full. Please try again later.')
        CancelEvent()
    end
end)