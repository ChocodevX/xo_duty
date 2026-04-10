local ESX = exports['es_extended']:getSharedObject()

-- [[ Variables & Tables ]]
local dutyRecords = {}
local onTime = {}
local playerCooldowns = {}

-- [[ 1. Helpers & Utilities ]]

local function Notify(source, message)
    
end

local function formatTime(totalSeconds)
    totalSeconds = tonumber(totalSeconds) or 0
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- ฟังก์ชันส่ง Log ไปยัง Discord (ปรับให้รองรับโครงสร้าง Config ใหม่)
local function LogToDiscord(xPlayer, actionEvent, actionMessage, color, jobKey)
    local webhookUrl = Config.Webhooks[jobKey] and Config.Webhooks[jobKey].duty
    if not webhookUrl then return end

    local playerSrc = xPlayer.source
    local identifiers = { discord = "Not Linked", steam = "Not Linked", ip = GetPlayerEndpoint(playerSrc) }

    for _, id in ipairs(GetPlayerIdentifiers(playerSrc)) do
        if string.find(id, "discord:") then identifiers.discord = string.sub(id, 9, -1)
        elseif string.find(id, "steam:") then identifiers.steam = id end
    end

    local embeds = {{
        ["color"] = tonumber(color),
        ["description"] = "### <t:" .. os.time() .. ":F>",
        ["fields"] = {
            { ["name"] = "Action", ["value"] = "```diff\n--- " .. actionEvent .. "\n" .. actionMessage .. "\n```" },
            { ["name"] = "Info", ["value"] = string.format("> - **Source:** %s [%s]\n> - **Discord:** <@%s>\n> - **Steam:** %s", xPlayer.getName(), playerSrc, identifiers.discord, identifiers.steam) }
        },
        ["footer"] = { ["text"] = "ELITE TOWN • " .. os.date("%Y/%m/%d %H:%M:%S") }
    }}

    PerformHttpRequest(webhookUrl, function() end, 'POST', json.encode({ username = "ELITE : LOG", embeds = embeds }), { ['Content-Type'] = 'application/json' })
end

-- [[ 2. Data Management (JSON) ]]

local function LoadDutyRecords()
    local data = LoadResourceFile(GetCurrentResourceName(), "dutyRecords.json")
    dutyRecords = data and json.decode(data) or {}
end

local function SaveDutyRecords()
    SaveResourceFile(GetCurrentResourceName(), "dutyRecords.json", json.encode(dutyRecords, {indent = true}), -1)
end

-- [[ 3. Item & Weapon Logic ]]

local function manageDutyGear(xPlayer, jobConfig, isJoining)
    -- จัดการ Items
    if jobConfig.items then
        for _, item in ipairs(jobConfig.items) do
            local currentCount = xPlayer.getInventoryItem(item.name).count
            if currentCount > 0 then xPlayer.removeInventoryItem(item.name, currentCount) end
            if isJoining then xPlayer.addInventoryItem(item.name, item.count) end
        end
    end
    -- จัดการ Weapons
    if jobConfig.weapons then
        for _, weapon in ipairs(jobConfig.weapons) do
            xPlayer.removeWeapon(weapon.name)
            if isJoining then xPlayer.addWeapon(weapon.name, weapon.ammo) end
        end
    end
end

-- [[ 4. Main Event ]]

RegisterNetEvent('elite_duty:toggle', function(currentJob)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    -- Cooldown 5 วินาที
    if playerCooldowns[_source] and (os.time() - playerCooldowns[_source]) < 5 then
        Notify(_source, "กรุณารอสักครู่ " .. (5 - (os.time() - playerCooldowns[_source])) .. " วินาที")
        return
    end
    playerCooldowns[_source] = os.time()

    -- ค้นหา Config ที่ตรงกับอาชีพปัจจุบัน
    local jobKey, jobConfig = nil, nil
    for k, v in pairs(Config.DutyJobs) do
        if currentJob == v.join or currentJob == v.leave then
            jobKey, jobConfig = k, v
            break
        end
    end

    if not jobConfig then return end

    local isOnDuty = (currentJob == jobConfig.join)

    if isOnDuty then -- กำลังจะ "ออกเวร"
        local elapsedTime = onTime[_source] and (os.time() - onTime[_source]) or 0
        manageDutyGear(xPlayer, jobConfig, false)
        xPlayer.setJob(jobConfig.leave, xPlayer.job.grade)
        
        local logMsg = string.format("- %s ได้ออกจากหน้าที่ %s\nเวลาทำงาน: %s", xPlayer.getName(), jobKey, formatTime(elapsedTime))
        
        if elapsedTime > 0 then
            if not dutyRecords[jobKey] then dutyRecords[jobKey] = {} end
            local found = false
            for _, rec in ipairs(dutyRecords[jobKey]) do
                if rec.Identifier == xPlayer.identifier then
                    rec.RecordTime = tostring((tonumber(rec.RecordTime) or 0) + elapsedTime)
                    found = true; break
                end
            end
            if not found then
                table.insert(dutyRecords[jobKey], { Name = xPlayer.getName(), Identifier = xPlayer.identifier, RecordTime = tostring(elapsedTime) })
            end
            SaveDutyRecords()
            Notify(_source, "ออกจากงานแล้ว (บันทึกเวลาเรียบร้อย)")
            LogToDiscord(xPlayer, "OFF DUTY", logMsg, 15105570, jobKey)
        else
            Notify(_source, "ออกจากงานแล้ว (ไม่พบเวลาทำงาน)")
            LogToDiscord(xPlayer, "OFF DUTY (No Time)", logMsg, 15548997, jobKey)
        end
        onTime[_source] = nil
    else -- กำลังจะ "เข้าเวร"
        manageDutyGear(xPlayer, jobConfig, true)
        xPlayer.setJob(jobConfig.join, xPlayer.job.grade)
        onTime[_source] = os.time()
        
        Notify(_source, "เข้างานแล้ว")
        LogToDiscord(xPlayer, "ON DUTY", "+ " .. xPlayer.getName() .. " เข้าปฏิบัติหน้าที่: " .. jobKey, 4052620, jobKey)
    end
end)

-- [[ 5. Automation & Summary ]]

local function GenerateSummary()
    LoadDutyRecords()
    if not next(dutyRecords) then return end

    for jobKey, recs in pairs(dutyRecords) do
        local webhook = Config.Webhooks[jobKey] and Config.Webhooks[jobKey].summary
        if webhook then
            table.sort(recs, function(a, b) return tonumber(a.RecordTime) > tonumber(b.RecordTime) end)

            local description = "### สรุปเวลาทำงานประจำวัน (" .. jobKey .. ") \n```\n"
            description = description .. "# | Time     | Name              | Steam Hex\n"
            description = description .. "--------------------------------------------------\n"

            for i, v in ipairs(recs) do
                local name = #v.Name > 17 and (string.sub(v.Name, 1, 14) .. "...") or v.Name
                description = description .. string.format("%-2d| %-8s| %-17s | %s\n", i, formatTime(v.RecordTime), name, v.Identifier:gsub("steam:", ""))
            end
            description = description .. "```"

            PerformHttpRequest(webhook, function() end, 'POST', json.encode({
                username = "สรุปเวลาทำงาน",
                embeds = {{ description = description, color = 3447003, footer = { text = "จำนวนผู้ปฏิบัติงาน: " .. #recs .. " คน" } }}
            }), { ['Content-Type'] = 'application/json' })
        end
    end

    dutyRecords = {}
    SaveDutyRecords()
end

-- Commands & Events
RegisterCommand('duty_summary', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.getGroup() == 'superadmin' then GenerateSummary() end
end)

AddEventHandler('playerDropped', function()
    local _source = source
    if onTime[_source] then
        local xPlayer = ESX.GetPlayerFromId(_source)
        if xPlayer then TriggerEvent('elite_duty:toggle', xPlayer.job.name) end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() == res then
        LoadDutyRecords()
        local hour = os.date("*t").hour
        if hour >= 0 and hour <= 1 then GenerateSummary() end
    end
end)