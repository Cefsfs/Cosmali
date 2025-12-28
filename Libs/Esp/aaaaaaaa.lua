-- TEST SCRIPT FOR DEBUGGING
print("=== ESP LIBRARY TEST SCRIPT ===")

-- Load the library
local success, ESP = pcall(function()
    return loadstring(game:HttpGet("YOUR_RAW_URL"))()
end)

if not success then
    print("ERROR: Failed to load ESP library")
    return
end

print("Library loaded successfully!")

-- Run the built-in test
print("\nRunning built-in test...")
ESP:Test()

-- Manual testing
print("\nManual testing...")

-- Test 1: Load CornerBox
print("\nTest 1: Loading CornerBox")
local loaded = ESP:LoadModule("CornerBox")
print("LoadModule returned: "..tostring(loaded))

-- Wait a bit
wait(2)

-- Test 2: Toggle it
print("\nTest 2: Toggling CornerBox")
local newState = ESP:ToggleModule("CornerBox")
print("New state: "..tostring(newState))

-- Wait a bit
wait(2)

-- Test 3: Toggle back
print("\nTest 3: Toggling CornerBox again")
newState = ESP:ToggleModule("CornerBox")
print("New state: "..tostring(newState))

-- Test 4: Update settings
print("\nTest 4: Updating settings")
ESP:UpdateSettings({
    TeamCheck = true,
    CornerBoxSettings = {
        Thickness = 4,
        AutoThickness = true
    }
})

print("Settings updated!")

-- Test 5: Test all functions
print("\nTest 5: Testing all functions")
print("Available modules:")
for name, module in pairs(ESP.Modules) do
    print("  - "..name.." (Enabled: "..tostring(module.Enabled)..")")
end

print("\n=== TEST COMPLETE ===")
print("Check the output for any errors!")
