<img width="500" height="500" alt="arenas_logo_mod" src="https://github.com/user-attachments/assets/92571d54-9a64-4b8a-8a32-bd6cab83e63e" />

# Brotato - Arenas Mod

A mod for the game [Brotato](https://store.steampowered.com/app/1942280/Brotato/) that adds new arena shapes you can pick from the run options menu. Each one changes the arena layout and how waves play out.

## Shapes

- **Default** — The default. Nothing new here.
- **Circle** — Round arena, no corners.
- **Hexagon** — Six-sided arena.
- **Curse Run** — Treadmill. You get pushed left, enemies come from the right. Keep moving or die.
- **Closing Storm** — Arena shrinks over time, battle royale style.
- **Maze** — Random maze walls every wave. New layout each time.
- **Caves** — Organic cave system with winding passages and varied chambers. Different layout every wave.
- **Hazard Zones** — Open arena with damaging curse clouds scattered around.
- **Roaming Hazards** — Curse clouds that drift and bounce around the arena. The danger never stops moving.
- **Meteor Shower** — Telegraphed meteors crash down and explode, hurting players and enemies alike. Small, medium, and large strikes, and the shower intensifies toward the end of each wave.
- **Safe Zone** — The whole arena is lethal except one roaming safe circle. Stay inside the ring of fire or take heavy damage.
- **Random** — Let the mod pick for you. See below for how to control it.

Maze and Caves regenerate every wave, and Roaming Hazards, Meteor Shower, and Safe Zone shift in real time during the wave — so no two waves play the same.

Your arena choice persists through save/resume.

## Random mode

Pick **Random** and a **Random Settings** button appears under the dropdown. Open it for a popup with:

- **Random Pool** — Check/uncheck which arena types are in the mix (all 11 are listed). Hate Curse Run on a slow character? Just uncheck it and Random will never roll it. Use **Select All** / **Clear** for quick changes. (If you clear everything, all shapes are used as a fallback.)
- **New arena each: Wave / Run** — Choose a fresh random arena every wave, or one random arena chosen at the start of the run and kept the whole way through. Defaults to once per run; change the default in the mod's config (`default_random_per_run`).

All Random settings persist through save/resume.

## Config

Tunable from the mod loader's config menu:

- `default_arena_shape` — The arena pre-selected in the dropdown (0–11).
- `shrinking_min_scale` / `shrinking_speed` — How small and how fast Closing Storm closes in.
- `meteor_interval` / `meteor_max_active` — How often meteors fall and how many can be telegraphing at once.
- `default_random_per_run` — Whether Random rerolls per run (true) or per wave (false).

## Compatibility

- Game version: 1.0.1.3
- Mod loader: 6.2.0
- No dependencies

## Languages

Translated in 12 languages: English, French, Spanish, German, Russian, Portuguese, Polish, Italian, Turkish, Chinese (Simplified & Traditional), and Japanese.

## Installation:
Just hit Subscribe, and the mod will be added to your game automatically. No setup required.

https://steamcommunity.com/sharedfiles/filedetails/?id=3689469294
