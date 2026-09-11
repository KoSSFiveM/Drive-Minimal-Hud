local hudEnabled = true
local inVehicle = false
local editMode = false
local layout = {
    x = 50.0,
    y = 9.0,
    scale = tonumber(Config.Scale) or 0.82
}

local limiter = {
    enabled = false,
    speed = tonumber(Config.LimiterDefault) or 130
}

local lastLimitedVehicle = 0
local KVP_KEY = 'drive_minimal_hud_layout'
local KVP_ENABLED_KEY = 'drive_minimal_hud_enabled'

-- Return whether the HUD should be visible / Kthen nëse HUD-i duhet të jetë i dukshëm
local function visible()
    return hudEnabled and (not Config.AutoHideOnFoot or inVehicle)
end

-- Keep a value inside its allowed range / Mban vlerën brenda kufijve të lejuar
local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

-- Convert configured HUD speed to meters per second / Kthen shpejtësinë e HUD-it në metra për sekondë
local function displaySpeedToMps(speed)
    if Config.Unit == 'mph' then
        return speed / 2.236936
    end

    return speed / 3.6
end

-- Reset the limiter on a vehicle / Rivendos kufirin e shpejtësisë së veturës
local function resetVehicleLimiter(vehicle)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleMaxSpeed(vehicle, 0.0)
    end
end

-- Apply the saved limiter to the current vehicle / Aplikon limituesin e ruajtur te vetura aktuale
local function applyVehicleLimiter(vehicle)
    if lastLimitedVehicle ~= 0 and lastLimitedVehicle ~= vehicle then
        resetVehicleLimiter(lastLimitedVehicle)
        lastLimitedVehicle = 0
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local ped = PlayerPedId()
    local isDriver = GetPedInVehicleSeat(vehicle, -1) == ped

    if limiter.enabled and isDriver then
        SetVehicleMaxSpeed(vehicle, displaySpeedToMps(limiter.speed))
        lastLimitedVehicle = vehicle
    else
        resetVehicleLimiter(vehicle)
        if lastLimitedVehicle == vehicle then
            lastLimitedVehicle = 0
        end
    end
end

-- Load the saved HUD layout from KVP / Ngarkon pozicionin e ruajtur të HUD-it nga KVP
local function loadLayout()
    local enabledRaw = GetResourceKvpString(KVP_ENABLED_KEY)
    if enabledRaw ~= nil and enabledRaw ~= '' then hudEnabled = enabledRaw == 'true' end

    local raw = GetResourceKvpString(KVP_KEY)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            layout.x = clamp(tonumber(data.x) or layout.x, 0.0, 100.0)
            layout.y = clamp(tonumber(data.y) or layout.y, 0.0, 95.0)
            layout.scale = clamp(tonumber(data.scale) or layout.scale, 0.45, 1.80)
        end
    end

end

-- Save the HUD layout in KVP / Ruan pozicionin e HUD-it në KVP
local function saveLayout()
    SetResourceKvp(KVP_KEY, json.encode(layout))
end

-- Send configuration and layout to the NUI / Dërgon konfigurimin dhe pozicionin te NUI
local function sync()
    SendNUIMessage({
        action = 'init',
        unit = Config.Unit,
        x = layout.x,
        bottom = layout.y,
        scale = layout.scale,
        maxRPM = Config.MaxRPM,
        redlineRPM = Config.RedlineRPM,
        hudEnabled = hudEnabled,
        limiterEnabled = limiter.enabled,
        limiterSpeed = limiter.speed,
        limiterMin = tonumber(Config.LimiterMin) or 20,
        limiterMax = tonumber(Config.LimiterMax) or 350,
        limiterStep = tonumber(Config.LimiterStep) or 5
    })
    SendNUIMessage({ action = 'visibility', visible = visible() })
end

-- Close HUD edit mode / Mbyll modalitetin e editimit të HUD-it
local function closeEditMode()
    if not editMode then return end

    editMode = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'editMode', enabled = false })
    SendNUIMessage({ action = 'visibility', visible = visible() })
end

-- Toggle HUD visibility / Aktivizon ose çaktivizon HUD-in
RegisterCommand('toggleminimalhud', function()
    hudEnabled = not hudEnabled

    if not hudEnabled then
        closeEditMode()
    end

    SendNUIMessage({ action = 'visibility', visible = visible() })
end, false)

RegisterKeyMapping('toggleminimalhud', 'Show/hide minimal vehicle HUD', 'keyboard', Config.ToggleKey)

-- Open or close layout editor with INSERT / Hap ose mbyll editorin me INSERT
RegisterCommand('editminimalhud', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 or not DoesEntityExist(veh) then
        closeEditMode()
        return
    end

    editMode = not editMode
    SendNUIMessage({ action = 'visibility', visible = editMode or visible() })
    SetNuiFocus(editMode, editMode)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'editMode', enabled = editMode })
end, false)

RegisterKeyMapping('editminimalhud', 'Edit minimal vehicle HUD', 'keyboard', Config.EditKey or 'INSERT')

-- NUI is ready / NUI është gati
RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
    Wait(50)
    sync()
end)

-- Save layout changes received from NUI / Ruan ndryshimet e pozicionit nga NUI
RegisterNUICallback('saveLayout', function(data, cb)
    layout.x = clamp(tonumber(data.x) or layout.x, 0.0, 100.0)
    layout.y = clamp(tonumber(data.bottom) or layout.y, 0.0, 95.0)
    layout.scale = clamp(tonumber(data.scale) or layout.scale, 0.45, 1.80)

    saveLayout()
    cb({ ok = true })
end)

-- Close edit mode from the NUI / Mbyll editimin nga NUI
RegisterNUICallback('closeEdit', function(_, cb)
    closeEditMode()
    cb({ ok = true })
end)

-- Reset layout from NUI icon / Rivendos pozicionin nga ikona e NUI
RegisterNUICallback('resetLayout', function(_, cb)
    layout.x = 50.0
    layout.y = tonumber(Config.Bottom) or 9.0
    layout.scale = tonumber(Config.Scale) or 0.82
    saveLayout()
    sync()
    SendNUIMessage({ action = 'editMode', enabled = editMode })
    cb({ ok = true })
end)

-- Save HUD visibility from NUI icon / Ruan dukshmërinë e HUD-it nga ikona e NUI
RegisterNUICallback('setHudEnabled', function(data, cb)
    hudEnabled = data.enabled == true
    SetResourceKvp(KVP_ENABLED_KEY, hudEnabled and 'true' or 'false')
    SendNUIMessage({ action = 'hudEnabled', enabled = hudEnabled })
    SendNUIMessage({ action = 'visibility', visible = editMode or visible() })
    cb({ ok = true })
end)

-- Update the speed limiter for this session only / Përditëson limituesin vetëm për këtë sesion
RegisterNUICallback('setLimiter', function(data, cb)
    limiter.enabled = data.enabled == true
    limiter.speed = clamp(
        tonumber(data.speed) or limiter.speed,
        tonumber(Config.LimiterMin) or 20,
        tonumber(Config.LimiterMax) or 350
    )

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    applyVehicleLimiter(veh)

    SendNUIMessage({
        action = 'limiter',
        enabled = limiter.enabled,
        speed = limiter.speed
    })

    cb({ ok = true })
end)

-- Load layout once when the resource starts / Ngarkon pozicionin kur nis resursa
CreateThread(function()
    loadLayout()
    Wait(500)
    sync()

    while true do
        Wait(2500)
        SendNUIMessage({ action = 'visibility', visible = editMode or visible() })
    end
end)

-- Detect electric vehicles with native support / Zbulon veturat elektrike me native
local function isVehicleElectric(vehicle)
    local model = GetEntityModel(vehicle)

    if GetIsVehicleElectric then
        local ok, result = pcall(GetIsVehicleElectric, model)
        if ok then
            return result == true or result == 1
        end
    end

    if GetGameBuildNumber() >= 3258 then
        local ok, result = pcall(Citizen.InvokeNative, 0x1FCB07FE230B6639, model)
        if ok then
            return result == true or result == 1
        end
    end

    return false
end

-- Update vehicle data at a controlled interval / Përditëson të dhënat e veturës me interval të kontrolluar
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local nowInVehicle = veh ~= 0 and DoesEntityExist(veh)

        if nowInVehicle ~= inVehicle then
            inVehicle = nowInVehicle

            if not inVehicle then
                closeEditMode()
                resetVehicleLimiter(lastLimitedVehicle)
                lastLimitedVehicle = 0
                if hudEnabled and Config.AutoHideOnFoot then
                    SendNUIMessage({ action = 'vehicleTransition', entering = false })
                else
                    SendNUIMessage({ action = 'visibility', visible = visible() })
                end
            else
                applyVehicleLimiter(veh)
                if hudEnabled then
                    SendNUIMessage({ action = 'vehicleTransition', entering = true })
                else
                    SendNUIMessage({ action = 'visibility', visible = false })
                end
            end
        end

        if nowInVehicle then
            applyVehicleLimiter(veh)
        end

        if nowInVehicle and visible() then
            sleep = math.max(40, tonumber(Config.UpdateInterval) or 75)

            local engineOn = GetIsVehicleEngineRunning(veh)
            local speed = GetEntitySpeed(veh) * (Config.Unit == 'mph' and 2.236936 or 3.6)
            local rpm = engineOn and (GetVehicleCurrentRpm(veh) * Config.MaxRPM) or 0.0
            local fuel = GetVehicleFuelLevel(veh)
            local gear = GetVehicleCurrentGear(veh)
            local temp = 30.0

            if GetVehicleEngineTemperature then
                local ok, value = pcall(GetVehicleEngineTemperature, veh)
                if ok and type(value) == 'number' and value > 0 then
                    temp = value
                end
            end

            SendNUIMessage({
                action = 'update',
                speed = math.floor(speed + 0.5),
                rpm = rpm,
                fuel = fuel,
                electric = isVehicleElectric(veh),
                gear = gear,
                temp = temp,
                limiterEnabled = limiter.enabled,
                limiterSpeed = limiter.speed
            })
        end

        Wait(sleep)
    end
end)

-- Remove the limiter when the resource stops / Heq limituesin kur ndalet resursa
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    resetVehicleLimiter(lastLimitedVehicle)
end)
