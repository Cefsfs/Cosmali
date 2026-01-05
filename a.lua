-- Stealthy table monitor - watches writes to specific tables
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character
local Humanoid = Character and Character:FindFirstChild("Humanoid")

-- Global storage for monitoring data (minimal)
local monitorData = {
    writes = {},
    accesses = {},
    lastUpdate = tick()
}

-- Function to stealthily attach monitor to a table
local function monitorTable(tbl, tableId)
    if not tbl or type(tbl) ~= "table" then return end
    
    local originalMt = getmetatable(tbl)
    if originalMt and (originalMt.__newindex or originalMt.__index) then
        -- Table already has metatable, monitor on top
        local origNewIndex = originalMt.__newindex
        local origIndex = originalMt.__index
        
        originalMt.__newindex = function(t, k, v)
            -- Record write
            if type(k) == "number" and (k == 7 or k == 10 or k == 2 or k == 0) then
                monitorData.writes[#monitorData.writes + 1] = {
                    table = tableId,
                    index = k,
                    value = tostring(v):sub(1, 100),
                    time = tick(),
                    type = typeof(v)
                }
                monitorData.lastUpdate = tick()
                
                -- Keep only last 50 writes
                if #monitorData.writes > 50 then
                    table.remove(monitorData.writes, 1)
                end
            end
            
            if origNewIndex then
                origNewIndex(t, k, v)
            else
                rawset(t, k, v)
            end
        end
        
        if origIndex then
            originalMt.__index = function(t, k)
                -- Record access
                if type(k) == "number" and (k == 7 or k == 10) then
                    monitorData.accesses[#monitorData.accesses + 1] = {
                        table = tableId,
                        index = k,
                        time = tick()
                    }
                    monitorData.lastUpdate = tick()
                    
                    if #monitorData.accesses > 50 then
                        table.remove(monitorData.accesses, 1)
                    end
                end
                
                return origIndex(t, k)
            end
        end
    else
        -- Create new metatable
        local mt = originalMt or {}
        
        mt.__newindex = function(t, k, v)
            -- Record write
            if type(k) == "number" and (k == 7 or k == 10 or k == 2 or k == 0) then
                monitorData.writes[#monitorData.writes + 1] = {
                    table = tableId,
                    index = k,
                    value = tostring(v):sub(1, 100),
                    time = tick(),
                    type = typeof(v)
                }
                monitorData.lastUpdate = tick()
                
                if #monitorData.writes > 50 then
                    table.remove(monitorData.writes, 1)
                end
            end
            
            rawset(t, k, v)
        end
        
        setmetatable(tbl, mt)
    end
    
    return true
end

-- Find and monitor tables (stealthy, one-time)
local function findAndMonitorTables()
    if not getgc then return 0 end
    
    task.wait(math.random(3, 7)) -- Random delay
    
    local gc = getgc()
    local monitored = 0
    
    -- Quick scan, minimal operations
    for _, v in pairs(gc) do
        if type(v) == "table" then
            -- Quick check without rawget
            if v[2] == Character then
                if monitorTable(v, "table_" .. monitored) then
                    monitored = monitored + 1
                end
                
                -- Limit to 3 tables to avoid detection
                if monitored >= 3 then break end
            end
        end
    end
    
    return monitored
end

-- Start monitoring after delay
task.delay(8, findAndMonitorTables)

-- Function to check monitored data (call when needed)
local function checkMonitorData()
    if tick() - monitorData.lastUpdate > 60 then
        -- No activity for 60 seconds, clear old data
        monitorData.writes = {}
        monitorData.accesses = {}
    end
    
    return {
        recentWrites = monitorData.writes,
        recentAccesses = monitorData.accesses,
        lastActivity = monitorData.lastUpdate
    }
end

-- Export check function
return {
    checkData = checkMonitorData,
    -- Call this when you want to see what's been recorded
    getLogs = function()
        local data = checkMonitorData()
        local output = ""
        
        if #data.recentWrites > 0 then
            output = output .. "Recent writes:\n"
            for i, write in ipairs(data.recentWrites) do
                output = output .. string.format("  [%s][%d] = %s (%s) @ %.2fs\n",
                    write.table, write.index, write.value, write.type,
                    tick() - write.time)
            end
        end
        
        if #data.recentAccesses > 0 then
            output = output .. "Recent accesses:\n"
            for i, access in ipairs(data.recentAccesses) do
                output = output .. string.format("  [%s][%d] accessed @ %.2fs\n",
                    access.table, access.index, tick() - access.time)
            end
        end
        
        return output
    end
}
