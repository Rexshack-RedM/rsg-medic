<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🏥 rsg-medic
**Complete medical and revive system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Advanced Medic system for RSG.  
> Includes full revive, heal, death timer, GPS call system, and medical stash support.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠  
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(prompts & notifications)*  
- [**rsg-inventory**](https://github.com/Rexshack-RedM/rsg-inventory) 🎒 *(Medic stash & bandage itMedic)*  
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(data persistence)*  

**Locales:** `en`, `fr`, `es`, `el`, `it`, `pt-br`, `ro`  
**SQL:** No additional tables required (uses `rsg-core` player data).

---

## ✨ Features

### ⚰️ Death & Respawn
- Player falls into **downed state** before dying.
- Automatic respawn after configurable delay (`Config.DeathTimer`).
- Respawn location configurable (default: Saint Denis Hospital).
- Revive via **[E] prompt** or **Medic intervention**.
- Configurable wipe options:
  - `Config.WipeInventoryOnRespawn`
  - `Config.WipeCashOnRespawn`
  - `Config.WipeBloodmoneyOnRespawn`

### ❤️ Medic Job
- Only players with job = `'medic'` can access Medic actions.
- Full revive and heal functionality with progress bar.
- GPS route auto‑enabled to emergency calls (`Config.AddGPSRoute`).
- Custom inventory/stash for Medic job (weight & slot limits).

### 💉 Healing
- `/heal <id>`: heals a player instantly (admin command).
- `bandage` item heals partially over time.
- Configurable healing amount and animation duration.

### ⚡ Reviving
- `/revive <id>`: admin revive command.
- Medic can manually revive nearby players.
- Revived players regain partial health:
  - `Config.ReviveHealth` for [E] revive
  - `Config.MedicReviveHealth` for Medic revive

### 🚨 Emergency Calls
- Players can send **medical distress calls** to all online medics.
- Calls have a cooldown (`Config.MedicCallDelay`) to prevent spam.
- GPS marker automatically attached for medics if `Config.AddGPSRoute = true`.

### 💼 Medic Storage
- Configurable stash for Medic use (via `rsg-inventory`).
- Adjustable slot & weight limits:
  ```lua
  Config.StorageMaxWeight = 4000000
  Config.StorageMaxSlots = 48
  ```

---

## ⚙️ Configuration

```lua
Config.Debug = false -- Enable/disable debug logs

-- Job
Config.JobRequired = 'medic'

-- Storage
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 48

-- Death System
Config.DeathTimer = 300 -- seconds
Config.WipeInventoryOnRespawn = false
Config.WipeCashOnRespawn = false
Config.WipeBloodmoneyOnRespawn = false

-- Health
Config.MaxHealth = 600
Config.MedicReviveTime = 5000 -- ms
Config.MedicTreatTime = 5000 -- ms
Config.MedicTreatHealth = 30 -- percent
Config.ReviveHealth = 20 -- player revive
Config.MedicReviveHealth = 60 -- Medic revive

-- Calls & GPS
Config.AddGPSRoute = true
Config.MedicCallDelay = 60 -- seconds cooldown between calls

-- Bandages
Config.BandageTime = 10000 -- ms
Config.BandageHealth = 15 -- percent restored
```

---

## 🧭 Example Usage

| Command | Description |
|----------|--------------|
| `/revive <id>` | Revives a dead player (admin) |
| `/heal <id>` | Heals a player to full health (admin) |


---

## 📂 Installation
1. Place `rsg-medic` in your `resources/[rsg]` folder.  
2. Ensure `rsg-core`, `rsg-inventory`, `ox_lib`, and `oxmysql` are installed.  
3. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-medic
   ```
4. Restart your server.

---

## 🌍 Locales
Included: `en`, `fr`, `es`, `el`, `it`, `pt-br`, `ro`  
Loaded automatically using `lib.locale()`.

---

## 💎 Credits
- **RSG / Rexshack-RedM** — core framework and Medic system  
- Community testers and translators  
- License: GPL‑3.0  
