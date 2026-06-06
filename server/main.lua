local ApartmentObjects = {}

local function CreateApartmentId(type)
    local UniqueFound = false
    local AparmentId = nil

    while not UniqueFound do
        AparmentId = tostring(math.random(1, 1000000))
        local result = MySQL.query.await('SELECT COUNT(*) as count FROM apartments WHERE name = ?', { tostring(type .. AparmentId) })
        if result[1].count == 0 then
            UniqueFound = true
        end
    end
    return AparmentId
end

local function GetApartmentInfo(apartmentId)
    local retval = nil
    local result = MySQL.query.await('SELECT * FROM apartments WHERE name = ?', { apartmentId })
    if result[1] ~= nil then
        retval = result[1]
    end
    return retval
end

RegisterNetEvent('qb-apartments:server:SetInsideMeta', function(house, insideId, bool, isVisiting)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    
    local insideMeta = Player.PlayerData.metadata['inside']

    if bool then
        local routeId = insideId:gsub('[^%-%d]', '')
        if not isVisiting then
            insideMeta.apartment.apartmentType = house
            insideMeta.apartment.apartmentId = insideId
            insideMeta.house = nil
            exports.qbx_core:SetMetadata(src, 'inside', insideMeta)
        end
        SetPlayerRoutingBucket(src, tonumber(routeId))
    else
        insideMeta.apartment.apartmentType = nil
        insideMeta.apartment.apartmentId = nil
        insideMeta.house = nil

        exports.qbx_core:SetMetadata(src, 'inside', insideMeta)
        SetPlayerRoutingBucket(src, 0)
    end
end)

RegisterNetEvent('qb-apartments:returnBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

RegisterNetEvent('apartments:server:openStash', function(CurrentApartment)
    local src = source
    exports.ox_inventory:RegisterStash(CurrentApartment, CurrentApartment, 50, 100000, false)
    TriggerClientEvent('apartments:client:openStash', src, CurrentApartment)
end)

RegisterNetEvent('apartments:server:CreateApartment', function(type, label, firstSpawn)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    
    local num = CreateApartmentId(type)
    local apartmentId = tostring(type .. num)
    label = tostring(label .. ' ' .. num)
    MySQL.insert('INSERT INTO apartments (name, type, label, citizenid) VALUES (?, ?, ?, ?)', {
        apartmentId,
        type,
        label,
        Player.PlayerData.citizenid
    })
    exports.qbx_core:Notify(src, Lang:t('success.receive_apart') .. ' (' .. label .. ')', 'success')
    if firstSpawn then
        TriggerClientEvent('apartments:client:SpawnInApartment', src, apartmentId, type)
    end
    TriggerClientEvent('apartments:client:SetHomeBlip', src, type)
end)

RegisterNetEvent('apartments:server:UpdateApartment', function(type, label)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    
    MySQL.update('UPDATE apartments SET type = ?, label = ? WHERE citizenid = ?', { type, label, Player.PlayerData.citizenid })
    exports.qbx_core:Notify(src, Lang:t('success.changed_apart'), 'success')
    TriggerClientEvent('apartments:client:SetHomeBlip', src, type)
end)

RegisterNetEvent('apartments:server:RingDoor', function(apartmentId, apartment)
    local src = source
    if ApartmentObjects[apartment].apartments[apartmentId] ~= nil and next(ApartmentObjects[apartment].apartments[apartmentId].players) ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments[apartmentId].players) do
            TriggerClientEvent('apartments:client:RingDoor', k, src)
        end
    end
end)

RegisterNetEvent('apartments:server:OpenDoor', function(target, apartmentId, apartment)
    local OtherPlayer = exports.qbx_core:GetPlayer(target)
    if OtherPlayer ~= nil then
        TriggerClientEvent('apartments:client:SpawnInApartment', OtherPlayer.PlayerData.source, apartmentId, apartment)
    end
end)

RegisterNetEvent('apartments:server:AddObject', function(apartmentId, apartment, offset)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    
    if ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil and ApartmentObjects[apartment].apartments[apartmentId] ~= nil then
        ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
    else
        if ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
            ApartmentObjects[apartment].apartments[apartmentId] = {}
            ApartmentObjects[apartment].apartments[apartmentId].offset = offset
            ApartmentObjects[apartment].apartments[apartmentId].players = {}
            ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
        else
            ApartmentObjects[apartment] = {}
            ApartmentObjects[apartment].apartments = {}
            ApartmentObjects[apartment].apartments[apartmentId] = {}
            ApartmentObjects[apartment].apartments[apartmentId].offset = offset
            ApartmentObjects[apartment].apartments[apartmentId].players = {}
            ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
        end
    end
end)

RegisterNetEvent('apartments:server:RemoveObject', function(apartmentId, apartment)
    local src = source
    if ApartmentObjects[apartment].apartments[apartmentId].players ~= nil then
        ApartmentObjects[apartment].apartments[apartmentId].players[src] = nil
        if next(ApartmentObjects[apartment].apartments[apartmentId].players) == nil then
            ApartmentObjects[apartment].apartments[apartmentId] = nil
        end
    end
end)

RegisterNetEvent('apartments:server:setCurrentApartment', function(ap)
    local Player = exports.qbx_core:GetPlayer(source)

    if not Player then return end

    exports.qbx_core:SetMetadata(source, 'currentapartment', ap)
end)

lib.callback.register('apartments:GetAvailableApartments', function(source, apartment)
    local apartments = {}
    if ApartmentObjects ~= nil and ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments) do
            if (ApartmentObjects[apartment].apartments[k] ~= nil and next(ApartmentObjects[apartment].apartments[k].players) ~= nil) then
                local apartmentInfo = GetApartmentInfo(k)
                apartments[k] = apartmentInfo.label
            end
        end
    end
    return apartments
end)

lib.callback.register('apartments:GetApartmentOffset', function(source, apartmentId)
    local retval = 0
    if ApartmentObjects ~= nil then
        for k, _ in pairs(ApartmentObjects) do
            if (ApartmentObjects[k].apartments[apartmentId] ~= nil and tonumber(ApartmentObjects[k].apartments[apartmentId].offset) ~= 0) then
                retval = tonumber(ApartmentObjects[k].apartments[apartmentId].offset)
            end
        end
    end
    return retval
end)

lib.callback.register('apartments:GetApartmentOffsetNewOffset', function(source, apartment)
    local retval = Apartments.SpawnOffset
    if ApartmentObjects ~= nil and ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments) do
            if (ApartmentObjects[apartment].apartments[k] ~= nil) then
                retval = ApartmentObjects[apartment].apartments[k].offset + Apartments.SpawnOffset
            end
        end
    end
    return retval
end)

lib.callback.register('apartments:GetOwnedApartment', function(source, cid)
    if cid ~= nil then
        local result = MySQL.query.await('SELECT * FROM apartments WHERE citizenid = ?', { cid })
        if result[1] ~= nil then
            return result[1]
        end
        return nil
    else
        local src = source
        local Player = exports.qbx_core:GetPlayer(src)
        if not Player then return nil end
        
        local result = MySQL.query.await('SELECT * FROM apartments WHERE citizenid = ?', { Player.PlayerData.citizenid })
        if result[1] ~= nil then
            return result[1]
        end
        return nil
    end
end)

lib.callback.register('apartments:IsOwner', function(source, apartment)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if Player ~= nil then
        local result = MySQL.query.await('SELECT * FROM apartments WHERE citizenid = ?', { Player.PlayerData.citizenid })
        if result[1] ~= nil then
            if result[1].type == apartment then
                return true
            else
                return false
            end
        else
            return false
        end
    end
    return false
end)

lib.callback.register('apartments:GetOutfits', function(source)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return nil end

    local result = MySQL.query.await('SELECT * FROM player_outfits WHERE citizenid = ?', { Player.PlayerData.citizenid })
    if result[1] ~= nil then
        return result
    end
    return nil
end)
