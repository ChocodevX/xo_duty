local ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}
local activeDutyConfig = nil -- เก็บค่า Config เฉพาะตอนที่อาชีพตรงเท่านั้น

-- Function หารูปแบบอาชีพว่าตรงกับ Config ไหม
local function CheckDutyJob(jobName)
    for _, v in pairs(Config.DutyJobs) do
        if jobName == v.join or jobName == v.leave then
            return v
        end
    end
    return nil
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    activeDutyConfig = CheckDutyJob(PlayerData.job.name)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    activeDutyConfig = CheckDutyJob(PlayerData.job.name)
end)

Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    PlayerData = ESX.GetPlayerData()
    if PlayerData.job then activeDutyConfig = CheckDutyJob(PlayerData.job.name) end
end)

-- Main Thread 
Citizen.CreateThread(function()
    while true do
        local sleep = 1000

        -- ทำงานก็ต่อเมื่ออาชีพของผู้เล่นมีสิทธิ์เข้าเวร-ออกเวรเท่านั้น
        if activeDutyConfig then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local jobName = PlayerData.job.name
            local isNearMarker = false

            for _, point in ipairs(activeDutyConfig.points) do
                local distance = #(coords - point)

                if distance < activeDutyConfig.distance then
                    isNearMarker = true
                    local isOffDuty = (jobName == activeDutyConfig.leave)
                    local Color = isOffDuty and { 245, 183, 111, 200 } or { 76, 10, 21, 255 }

                    DrawMarker(27, point.x, point.y, point.z - 0.8, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, Color[1], Color[2], Color[3], Color[4], 0, 0, 0, 0)

                    if distance < 2.0 then
                        ESX.ShowHelpNotification('<font face="font4thai">~w~ กด [~y~E~w~] เพื่อ ' .. (isOffDuty and 'เข้า' or 'ออก') .. ' หน้าที่</font>')
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('elite_duty:toggle', jobName)
                            Wait(1000)
                        end
                    end
                end
            end

            if isNearMarker then sleep = 0 end
        end

        Wait(sleep)
    end
end)