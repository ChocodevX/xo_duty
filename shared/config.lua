Config = {}
Config.Debug = false

-- กำหนด Webhook แยกไว้ (ดึงไปใช้เฉพาะฝั่ง Server)
Config.Webhooks = {
    police = {
        duty = "YOUR_WEBHOOK_HERE",
        summary = "YOUR_WEBHOOK_HERE"
    },
    ambulance = {
        duty = "YOUR_WEBHOOK_HERE",
        summary = "YOUR_WEBHOOK_HERE"
    },
    gouvernment = {
        duty = "YOUR_WEBHOOK_HERE",
        summary = "YOUR_WEBHOOK_HERE"
    }
}

Config.DutyJobs = {
    ['police'] = { -- แนะนำให้ใช้ Key เป็นชื่ออาชีพ (Join) ไปเลยเพื่อให้เช็คง่ายขึ้น
        join = 'police',
        leave = 'offpolice',
        distance = 4.0,
        points = {
            vector3(443.67, -987.01, 30.24),
        },
        items = { { name = 'items', count = 1 } },
        weapons = { { name = 'WEAPON_STUNGUN', ammo = 1 } }
    },
    ['ambulance'] = {
        join = 'ambulance',
        leave = 'offambulance',
        distance = 4.0,
        points = {
        },
        items = { { name = 'items', count = 1 } },
        weapons = {}
    },
    ['gouvernment'] = {
        join = 'gouvernment',
        leave = 'offgouvernment',
        distance = 4.0,
        points = {
            vector3(-553.22, -203.12, 38.23)
        },
        items = { { name = 'items', count = 1 } },
        weapons = {}
    }
}