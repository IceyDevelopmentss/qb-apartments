local UseTarget = GetConvar('UseTarget', 'false') == 'true'
local InApartment = false
local ClosestHouse = nil
local CurrentApartment = nil
local IsOwned = false
local CurrentDoorBell = 0
local CurrentOffset = 0
local HouseObj = {}
local POIOffsets = nil
local RangDoorbell = nil

local InApartmentTargets = {}

local IsInsideEntranceZone = false
local IsInsideExitZone = false
local IsInsideStashZone = false
local IsInsideOutfitsZone = false
local IsInsideLogoutZone = false

local function OpenEntranceMenu()
    local options = {}

    if IsOwned then
        options[#options + 1] = {
            title = Lang:t('text.enter'),
            icon = 'door-open',
            event = 'apartments:client:EnterApartment',
        }
    else
        options[#options + 1] = {
            title = Lang:t('text.move_here'),
            icon = 'hotel',
            event = 'apartments:client:UpdateApartment',
        }
    end

    options[#options + 1] = {
        title = Lang:t('text.ring_doorbell'),
        icon = 'bell-concierge',
        event = 'apartments:client:DoorbellMenu',
    }

    lib.registerContext({
        id = 'apartment_entrance_menu',
        title = Lang:t('text.options'),
        options = options,
    })

    lib.showContext('apartment_entrance_menu')
end

local function OpenExitMenu()
    lib.registerContext({
        id = 'apartment_exit_menu',
        title = Lang:t('text.options'),
        options = {
            {
                title = Lang:t('text.open_door'),
                icon = 'door-open',
                event = 'apartments:client:OpenDoor',
            },
            {
                title = Lang:t('text.leave'),
                icon = 'right-from-bracket',
                event = 'apartments:client:LeaveApartment',
            },
        },
    })

    lib.showContext('apartment_exit_menu')
end

local function RegisterApartmentEntranceZone(apartmentID, apartmentData)
    local coords = apartmentData.coords['enter']
    local boxName = 'apartmentEntrance_' .. apartmentID
    local boxData = apartmentData.polyzoneBoxData

    if boxData.created then
        return
    end

    local zone = BoxZone:Create(coords, boxData.length, boxData.width, {
        name = boxName,
        heading = 340.0,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside and not InApartment then
            lib.showTextUI(Lang:t('text.options'))
        else
            lib.hideTextUI()
        end
        IsInsideEntranceZone = isPointInside
    end)

    boxData.created = true
    boxData.zone = zone
end

local function RegisterApartmentEntranceTarget(apartmentID, apartmentData)
    local coords = apartmentData.coords['enter']
    local boxName = 'apartmentEntrance_' .. apartmentID
    local boxData = apartmentData.polyzoneBoxData

    if boxData.created then
        return
    end

    local options = {}
    
    if apartmentID == ClosestHouse and IsOwned then
        options[#options + 1] = {
            label = Lang:t('text.enter'),
            icon = 'fa-solid fa-door-open',
            distance = boxData.distance,
            onSelect = function()
                TriggerEvent('apartments:client:EnterApartment')
            end,
        }
    else
        options[#options + 1] = {
            label = Lang:t('text.move_here'),
            icon = 'fa-solid fa-hotel',
            distance = boxData.distance,
            onSelect = function()
                TriggerEvent('apartments:client:UpdateApartment')
            end,
        }
    end
    
    options[#options + 1] = {
        label = Lang:t('text.ring_doorbell'),
        icon = 'fa-solid fa-bell-concierge',
        distance = boxData.distance,
        onSelect = function()
            TriggerEvent('apartments:client:DoorbellMenu')
        end,
    }

    exports.ox_target:addBoxZone({
        name = boxName,
        coords = coords,
        size = vec3(boxData.length, boxData.width, 2.0),
        rotation = boxData.heading,
        debug = boxData.debug,
        options = options,
    })

    boxData.created = true
end

local function RegisterInApartmentZone(targetKey, coords, heading, text)
    if not InApartment then
        return
    end

    if InApartmentTargets[targetKey] and InApartmentTargets[targetKey].created then
        return
    end

    Wait(1500)

    local boxName = 'inApartmentTarget_' .. targetKey

    local zone = BoxZone:Create(coords, 1.5, 1.5, {
        name = boxName,
        heading = heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside and text then
            lib.showTextUI(text)
        else
            lib.hideTextUI()
        end

        if targetKey == 'entrancePos' then
            IsInsideExitZone = isPointInside
        end

        if targetKey == 'stashPos' then
            IsInsideStashZone = isPointInside
        end

        if targetKey == 'outfitsPos' then
            IsInsideOutfitsZone = isPointInside
        end

        if targetKey == 'logoutPos' then
            IsInsideLogoutZone = isPointInside
        end
    end)

    InApartmentTargets[targetKey] = InApartmentTargets[targetKey] or {}
    InApartmentTargets[targetKey].created = true
    InApartmentTargets[targetKey].zone = zone
end

local function RegisterInApartmentTarget(targetKey, coords, heading, options)
    if not InApartment then
        return
    end

    if InApartmentTargets[targetKey] and InApartmentTargets[targetKey].created then
        return
    end

    local boxName = 'inApartmentTarget_' .. targetKey
    
    exports.ox_target:addBoxZone({
        name = boxName,
        coords = coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = heading,
        debug = false,
        options = options,
    })

    InApartmentTargets[targetKey] = InApartmentTargets[targetKey] or {}
    InApartmentTargets[targetKey].created = true
end

local function SetApartmentsEntranceTargets()
    if Apartments.Locations and next(Apartments.Locations) then
        for id, apartment in pairs(Apartments.Locations) do
            if apartment and apartment.coords and apartment.coords['enter'] then
                if UseTarget then
                    RegisterApartmentEntranceTarget(id, apartment)
                else
                    RegisterApartmentEntranceZone(id, apartment)
                end
            end
        end
    end
end

local function SetInApartmentTargets()
    if not POIOffsets then
        return
    end

    local entrancePos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x + POIOffsets.exit.x, Apartments.Locations[ClosestHouse].coords.enter.y + POIOffsets.exit.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.exit.z)
    local stashPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.stash.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.stash.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.stash.z)
    local outfitsPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.clothes.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.clothes.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.clothes.z)
    local logoutPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.logout.x, Apartments.Locations[ClosestHouse].coords.enter.y + POIOffsets.logout.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.logout.z)

    if UseTarget then
        RegisterInApartmentTarget('entrancePos', entrancePos, 0, {
            {
                label = Lang:t('text.open_door'),
                icon = 'fa-solid fa-door-open',
                distance = 1.5,
                onSelect = function()
                    TriggerEvent('apartments:client:OpenDoor')
                end,
            },
            {
                label = Lang:t('text.leave'),
                icon = 'fa-solid fa-right-from-bracket',
                distance = 1.5,
                onSelect = function()
                    TriggerEvent('apartments:client:LeaveApartment')
                end,
            },
        })
        RegisterInApartmentTarget('stashPos', stashPos, 0, {
            {
                label = Lang:t('text.open_stash'),
                icon = 'fa-solid fa-box-open',
                distance = 1.5,
                onSelect = function()
                    TriggerEvent('apartments:client:OpenStash')
                end,
            },
        })
        RegisterInApartmentTarget('outfitsPos', outfitsPos, 0, {
            {
                label = Lang:t('text.change_outfit'),
                icon = 'fa-solid fa-shirt',
                distance = 1.5,
                onSelect = function()
                    TriggerEvent('apartments:client:ChangeOutfit')
                end,
            },
        })
        RegisterInApartmentTarget('logoutPos', logoutPos, 0, {
            {
                label = Lang:t('text.logout'),
                icon = 'fa-solid fa-right-from-bracket',
                distance = 1.5,
                onSelect = function()
                    TriggerEvent('apartments:client:Logout')
                end,
            },
        })
    else
        RegisterInApartmentZone('stashPos', stashPos, 0, '[E] ' .. Lang:t('text.open_stash'))
        RegisterInApartmentZone('outfitsPos', outfitsPos, 0, '[E] ' .. Lang:t('text.change_outfit'))
        RegisterInApartmentZone('logoutPos', logoutPos, 0, '[E] ' .. Lang:t('text.logout'))
        RegisterInApartmentZone('entrancePos', entrancePos, 0, Lang:t('text.options'))
    end
end

local function DeleteApartmentsEntranceTargets()
    if Apartments.Locations and next(Apartments.Locations) then
        for id, apartment in pairs(Apartments.Locations) do
            if UseTarget then
                exports.ox_target:removeZone('apartmentEntrance_' .. id)
            else
                if apartment.polyzoneBoxData.zone then
                    apartment.polyzoneBoxData.zone:destroy()
                    apartment.polyzoneBoxData.zone = nil
                end
            end
            apartment.polyzoneBoxData.created = false
        end
    end
end

local function DeleteInApartmentTargets()
    IsInsideExitZone = false
    IsInsideStashZone = false
    IsInsideOutfitsZone = false
    IsInsideLogoutZone = false

    if InApartmentTargets and next(InApartmentTargets) then
        for id, apartmentTarget in pairs(InApartmentTargets) do
            if UseTarget then
                exports.ox_target:removeZone('inApartmentTarget_' .. id)
            else
                if apartmentTarget.zone then
                    apartmentTarget.zone:destroy()
                    apartmentTarget.zone = nil
                end
            end
        end
    end
    InApartmentTargets = {}
end

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function openHouseAnim()
    loadAnimDict('anim@heists@keycard@')
    TaskPlayAnim(PlayerPedId(), 'anim@heists@keycard@', 'exit', 5.0, 1.0, -1, 16, 0, 0, 0, 0)
    Wait(400)
    ClearPedTasks(PlayerPedId())
end

local function EnterApartment(house, apartmentId, new)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()
    Wait(250)
    local offset = lib.callback.await('apartments:GetApartmentOffset', false, apartmentId)
    if offset == nil or offset == 0 then
        local newoffset = lib.callback.await('apartments:GetApartmentOffsetNewOffset', false, house)
        if newoffset > 230 then
            newoffset = 210
        end
        CurrentOffset = newoffset
        TriggerServerEvent('apartments:server:AddObject', apartmentId, house, CurrentOffset)
        local coords = { x = Apartments.Locations[house].coords.enter.x, y = Apartments.Locations[house].coords.enter.y, z = Apartments.Locations[house].coords.enter.z - CurrentOffset }
        local data = exports['qb-interior']:CreateApartmentFurnished(coords)
        Wait(100)
        HouseObj = data[1]
        POIOffsets = data[2]
        InApartment = true
        CurrentApartment = apartmentId
        ClosestHouse = house
        RangDoorbell = nil
        Wait(500)
        TriggerEvent('qb-weathersync:client:DisableSync')
        Wait(100)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, false)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
        TriggerServerEvent('apartments:server:setCurrentApartment', CurrentApartment)
    else
        if offset > 230 then
            offset = 210
        end
        CurrentOffset = offset
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
        TriggerServerEvent('apartments:server:AddObject', apartmentId, house, CurrentOffset)
        local coords = { x = Apartments.Locations[ClosestHouse].coords.enter.x, y = Apartments.Locations[ClosestHouse].coords.enter.y, z = Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset }
        local data = exports['qb-interior']:CreateApartmentFurnished(coords)
        Wait(100)
        HouseObj = data[1]
        POIOffsets = data[2]
        InApartment = true
        CurrentApartment = apartmentId
        Wait(500)
        TriggerEvent('qb-weathersync:client:DisableSync')
        Wait(100)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, true)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
        TriggerServerEvent('apartments:server:setCurrentApartment', CurrentApartment)
    end

    if new ~= nil then
        if new then
            TriggerEvent('qb-interior:client:SetNewState', true)
        else
            TriggerEvent('qb-interior:client:SetNewState', false)
        end
    else
        TriggerEvent('qb-interior:client:SetNewState', false)
    end
end

local function LeaveApartment(house)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()
    TriggerServerEvent('qb-apartments:returnBucket')
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    exports['qb-interior']:DespawnInterior(HouseObj, function()
        TriggerEvent('qb-weathersync:client:EnableSync')
        SetEntityCoords(PlayerPedId(), Apartments.Locations[house].coords.enter.x, Apartments.Locations[house].coords.enter.y, Apartments.Locations[house].coords.enter.z)
        SetEntityHeading(PlayerPedId(), Apartments.Locations[house].coords.enter.w)
        Wait(1000)
        TriggerServerEvent('apartments:server:RemoveObject', CurrentApartment, house)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', CurrentApartment, false)
        CurrentApartment = nil
        InApartment = false
        CurrentOffset = 0
        DoScreenFadeIn(1000)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
        TriggerServerEvent('apartments:server:setCurrentApartment', nil)

        DeleteInApartmentTargets()
        DeleteApartmentsEntranceTargets()
    end)
end

local function SetClosestApartment()
    local pos = GetEntityCoords(PlayerPedId())
    local current = nil
    local dist = 100
    for id, _ in pairs(Apartments.Locations) do
        local distcheck = #(pos - vector3(Apartments.Locations[id].coords.enter.x, Apartments.Locations[id].coords.enter.y, Apartments.Locations[id].coords.enter.z))
        if distcheck < dist then
            current = id
        end
    end
    if current ~= ClosestHouse and LocalPlayer.state.isLoggedIn and not InApartment then
        ClosestHouse = current
        local result = lib.callback.await('apartments:IsOwner', false, ClosestHouse)
        IsOwned = result
        DeleteApartmentsEntranceTargets()
        DeleteInApartmentTargets()
    end
end

function MenuOwners()
    local apartments = lib.callback.await('apartments:GetAvailableApartments', false, ClosestHouse)
    if next(apartments) == nil then
        lib.notify({
            title = Lang:t('error.nobody_home'),
            type = 'error',
        })
        return
    end

    local options = {}

    for k, v in pairs(apartments) do
        options[#options + 1] = {
            title = v,
            event = 'apartments:client:RingMenu',
            args = { apartmentId = k },
        }
    end

    lib.registerContext({
        id = 'apartment_tennants_menu',
        title = Lang:t('text.tennants'),
        options = options,
    })

    lib.showContext('apartment_tennants_menu')
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if HouseObj ~= nil then
            exports['qb-interior']:DespawnInterior(HouseObj, function()
                CurrentApartment = nil
                TriggerEvent('qb-weathersync:client:EnableSync')
                DoScreenFadeIn(500)
                while not IsScreenFadedOut() do
                    Wait(10)
                end
                SetEntityCoords(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.x, Apartments.Locations[ClosestHouse].coords.enter.y, Apartments.Locations[ClosestHouse].coords.enter.z)
                SetEntityHeading(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.w)
                Wait(1000)
                InApartment = false
                DoScreenFadeIn(1000)
            end)
        end

        DeleteApartmentsEntranceTargets()
        DeleteInApartmentTargets()
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    CurrentApartment = nil
    InApartment = false
    CurrentOffset = 0

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)

RegisterNetEvent('apartments:client:setupSpawnUI', function(cData)
    local result = lib.callback.await('apartments:GetOwnedApartment', false, cData.citizenid)
    if result then
        TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
        TriggerEvent('qb-spawn:client:openUI', true)
        TriggerEvent('apartments:client:SetHomeBlip', result.type)
    else
        if Apartments.Starting then
            TriggerEvent('qb-spawn:client:setupSpawns', cData, true, Apartments.Locations)
            TriggerEvent('qb-spawn:client:openUI', true)
        else
            TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
            TriggerEvent('qb-spawn:client:openUI', true)
            TriggerEvent('apartments:client:SetHomeBlip', nil)
        end
    end
end)

RegisterNetEvent('apartments:client:SpawnInApartment', function(apartmentId, apartment)
    local pos = GetEntityCoords(PlayerPedId())
    if RangDoorbell ~= nil then
        local doorbelldist = #(pos - vector3(Apartments.Locations[RangDoorbell].coords.enter.x, Apartments.Locations[RangDoorbell].coords.enter.y, Apartments.Locations[RangDoorbell].coords.enter.z))
        if doorbelldist > 5 then
            lib.notify({
                title = Lang:t('error.to_far_from_door'),
                type = 'error',
            })
            return
        end
    end
    ClosestHouse = apartment
    EnterApartment(apartment, apartmentId, true)
    IsOwned = true
end)

RegisterNetEvent('qb-apartments:client:LastLocationHouse', function(apartmentType, apartmentId)
    ClosestHouse = apartmentType
    EnterApartment(apartmentType, apartmentId, false)
end)

RegisterNetEvent('apartments:client:SetHomeBlip', function(home)
    CreateThread(function()
        SetClosestApartment()
        for name, _ in pairs(Apartments.Locations) do
            RemoveBlip(Apartments.Locations[name].blip)

            Apartments.Locations[name].blip = AddBlipForCoord(Apartments.Locations[name].coords.enter.x, Apartments.Locations[name].coords.enter.y, Apartments.Locations[name].coords.enter.z)
            if (name == home) then
                SetBlipSprite(Apartments.Locations[name].blip, 475)
                SetBlipCategory(Apartments.Locations[name].blip, 11)
            else
                SetBlipSprite(Apartments.Locations[name].blip, 476)
                SetBlipCategory(Apartments.Locations[name].blip, 10)
            end
            SetBlipDisplay(Apartments.Locations[name].blip, 4)
            SetBlipScale(Apartments.Locations[name].blip, 0.65)
            SetBlipAsShortRange(Apartments.Locations[name].blip, true)
            SetBlipColour(Apartments.Locations[name].blip, 3)
            AddTextEntry(Apartments.Locations[name].label, Apartments.Locations[name].label)
            BeginTextCommandSetBlipName(Apartments.Locations[name].label)
            EndTextCommandSetBlipName(Apartments.Locations[name].blip)
        end
    end)
end)

RegisterNetEvent('apartments:client:RingMenu', function(data)
    RangDoorbell = ClosestHouse
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TriggerServerEvent('apartments:server:RingDoor', data.apartmentId, ClosestHouse)
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    CurrentDoorBell = player
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    lib.notify({
        title = Lang:t('info.at_the_door'),
        type = 'inform',
    })
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function()
    MenuOwners()
end)

RegisterNetEvent('apartments:client:EnterApartment', function()
    local result = lib.callback.await('apartments:GetOwnedApartment', false)
    if result ~= nil then
        EnterApartment(ClosestHouse, result.name)
    end
end)

RegisterNetEvent('apartments:client:UpdateApartment', function()
    local apartmentType = ClosestHouse
    local apartmentLabel = Apartments.Locations[ClosestHouse].label
    local result = lib.callback.await('apartments:GetOwnedApartment', false)
    if result == nil then
        TriggerServerEvent('apartments:server:CreateApartment', apartmentType, apartmentLabel, false)
    else
        TriggerServerEvent('apartments:server:UpdateApartment', apartmentType, apartmentLabel)
    end

    IsOwned = true

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if CurrentDoorBell == 0 then
        lib.notify({
            title = Lang:t('error.nobody_at_door'),
            type = 'error',
        })
        return
    end
    TriggerServerEvent('apartments:server:OpenDoor', CurrentDoorBell, CurrentApartment, ClosestHouse)
    CurrentDoorBell = 0
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    LeaveApartment(ClosestHouse)
end)

RegisterNetEvent('apartments:client:OpenStash', function()
    if CurrentApartment then
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'StashOpen', 0.4)
        TriggerServerEvent('apartments:server:openStash', CurrentApartment)
    end
end)

RegisterNetEvent('apartments:client:openStash', function(stashId)
    exports.ox_inventory:openInventory('stash', {id = stashId})
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'Clothes1', 0.4)
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('apartments:client:Logout', function()
    TriggerServerEvent('qb-houses:server:LogoutLocation')
end)

if UseTarget then
    CreateThread(function()
        local sleep = 5000
        while not LocalPlayer.state.isLoggedIn do
            Wait(sleep)
        end

        while true do
            sleep = 1000

            if not InApartment then
                SetClosestApartment()
                SetApartmentsEntranceTargets()
            elseif InApartment then
                SetInApartmentTargets()
            end
            Wait(sleep)
        end
    end)
else
    CreateThread(function()
        local sleep = 5000
        while not LocalPlayer.state.isLoggedIn do
            Wait(sleep)
        end

        while true do
            sleep = 1000

            if not InApartment then
                SetClosestApartment()
                SetApartmentsEntranceTargets()

                if IsInsideEntranceZone then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        OpenEntranceMenu()
                        lib.hideTextUI()
                    end
                end
            elseif InApartment then
                sleep = 0

                SetInApartmentTargets()

                if IsInsideExitZone then
                    if IsControlJustPressed(0, 38) then
                        OpenExitMenu()
                        lib.hideTextUI()
                    end
                end

                if IsInsideStashZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('apartments:client:OpenStash')
                        lib.hideTextUI()
                    end
                end

                if IsInsideOutfitsZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('apartments:client:ChangeOutfit')
                        lib.hideTextUI()
                    end
                end

                if IsInsideLogoutZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerClientEvent('um-multicharacter:client:logout', src)
                        lib.hideTextUI()
                    end
                end
            end

            Wait(sleep)
        end
    end)
end
