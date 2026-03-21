# PapiLeem-Arenas Mod Plan

## Context
The Brotato arena is hardcoded as a rectangle at every layer: collision walls, position clamping, enemy spawning, tile fill, and visual border. This mod adds player-selectable arena shapes (Circle, Hexagon, Diamond, Closing Storm) via a unified `ArenaShape` abstraction that all game systems delegate to. The player picks a shape before each run from the difficulty selection screen.

---

## Mod File Structure

```
mods-unpacked/PapiLeem-Arenas/
  manifest.json
  mod_main.gd
  arena_shapes/
    arena_shape.gd              # Base class with uniform API
    rectangle_shape.gd          # Vanilla behavior (no-op)
    circle_shape.gd
    hexagon_shape.gd
    diamond_shape.gd
    shrinking_shape.gd
  extensions/
    singletons/
      run_data.gd               # Add arena_shape_id + arena_shape instance
      zone_service.gd           # Shape-aware get_rand_pos, set_current_zone
    entities/units/unit/
      unit.gd                   # Shape-aware _integrate_forces clamping
    global/
      my_tile_map_limits.gd     # Shape-specific collision walls
      my_tile_map.gd            # Shape-specific tile fill + outline
      entity_spawner.gd         # Shape-aware edge spawning
    main.gd                     # Shape setup, outline drawing, shrinking timer
    ui/menus/run/difficulty_selection/
      difficulty_selection.gd   # OptionButton for shape selection
  translations/
    arena_translations.gd       # i18n strings
```

---

## Core Design: ArenaShape Base Class

`arena_shapes/arena_shape.gd` provides a uniform API all extensions call into:

| Method | Purpose |
|--------|---------|
| `setup(width_px, height_px)` | Initialize from zone dimensions |
| `contains_point(pos) -> bool` | Is point inside the arena? |
| `clamp_position(pos) -> Vector2` | Nearest point inside boundary |
| `get_rand_pos(edge) -> Vector2` | Random position with edge buffer |
| `get_rand_edge_pos(dist) -> Vector2` | Random position on arena edge |
| `get_collision_polygon_points() -> PoolVector2Array` | Wall vertices |
| `should_fill_tile(i, j, tile_size) -> bool` | Should this tile be drawn? |
| `get_outline_points() -> PoolVector2Array` | Visual border vertices |
| `update(time_ratio)` | Per-frame update (shrinking only) |

Each shape subclass overrides these. Extensions stay thin -- they just delegate to `RunData.arena_shape.<method>`.

---

## Shape Implementations

### Rectangle (default)
- `contains_point`: `Rect2.has_point()` -- identical to vanilla
- `clamp_position`: per-axis `clamp()` -- identical to vanilla
- Collision: 4 rectangle walls (vanilla behavior)
- Tile fill: all tiles (vanilla)
- Ensures mod is a no-op when Rectangle is selected

### Circle
- Inscribed circle: `radius = min(half_width, half_height)`
- `contains_point`: `(pos - center).length_squared() <= radius * radius`
- `clamp_position`: project onto circle edge via normalized direction
- `get_rand_pos`: polar coords -- `angle = rand(0, TAU)`, `r = radius * sqrt(randf())`
- `get_rand_edge_pos`: random angle, place at `radius - dist` from center
- Collision: 32-segment `ConvexPolygonShape2D` polygon approximation
- Tile fill: check tile center distance from center

### Hexagon
- Regular hexagon inscribed in bounding circle, 6 vertices at 60-degree intervals
- `contains_point`: check against 6 half-planes
- Collision: 6 thick wall segments or single ConvexPolygonShape2D
- Spawning: pick random edge (1 of 6), random position along it

### Diamond
- Rotated 45-degree square: `abs(x - cx)/hw + abs(y - cy)/hh <= 1`
- `clamp_position`: project onto nearest of 4 diagonal edges
- Collision: 4 angled wall segments

### Closing Storm (Battle Royale)
- Starts as full rectangle, linearly shrinks to `shrinking_min_scale` (configurable, default 0.4)
- `update(time_ratio)` called from main.gd each physics frame during wave
- Position clamping adapts automatically (checks current scale each frame)
- Collision walls rebuilt every ~0.5s (not every frame) via timer
- Visual: overlay Node2D draws the "danger zone" outside current boundary
- Optional damage-per-second when outside shrunk zone (configurable)

---

## Script Extensions (6 systems to modify)

### 1. `extensions/singletons/run_data.gd`
- Add `var arena_shape_id: int = 0` and `var arena_shape: Reference = null`
- Override `reset()` to preserve shape_id on run restart
- Override `get_state()`/`resume_from_state()` for save/load

### 2. `extensions/singletons/zone_service.gd`
- Override `set_current_zone()`: after calling parent, call `RunData.arena_shape.setup(zone_width_px, zone_height_px)` -- this ensures shape is configured before tile_map and tile_map_limits init
- Override `get_rand_pos(edge)`: delegate to `RunData.arena_shape.get_rand_pos(edge)`
- Override `get_rand_pos_in_area()`: clamp results with shape

### 3. `extensions/entities/units/unit/unit.gd`
- Override `_integrate_forces(state)`: replace rectangular `zone_rect.has_point()` + per-axis clamp with `arena_shape.contains_point()` + `arena_shape.clamp_position()`
- Copy full method from base unit.gd:164-211, only modify the containment block

### 4. `extensions/global/my_tile_map_limits.gd`
- Override `init(zone)`: for Rectangle call parent; for other shapes create polygon-based collision walls from `arena_shape.get_collision_polygon_points()`
- Each polygon edge becomes a thick wall segment (4-tile-deep trapezoid)

### 5. `extensions/global/my_tile_map.gd`
- Override `init(zone)`: iterate tiles, only fill where `arena_shape.should_fill_tile(i, j)` is true
- Hide vanilla `NinePatchRect` outline for non-rectangle shapes
- Add custom `Line2D` or `_draw()` node for shape outline

### 6. `extensions/global/entity_spawner.gd`
- Override `get_spawn_pos_in_area()`: when `spawn_edge_of_map` is true, use `arena_shape.get_rand_edge_pos()` instead of TOP/LEFT/BOTTOM/RIGHT logic
- When `area == -1`: use `arena_shape.get_rand_pos(d)` instead of rectangular rand_range

### 7. `extensions/main.gd`
- Instantiate correct ArenaShape subclass from `RunData.arena_shape_id` before `._ready()`
- For shrinking shape: add timer to call `arena_shape.update()` and periodically rebuild walls
- Add custom outline drawing node for non-rectangle shapes

### 8. `extensions/ui/menus/run/difficulty_selection/difficulty_selection.gd`
- Add `OptionButton` with items: Rectangle, Circle, Hexagon, Diamond, Closing Storm
- Follow HoardMode pattern: create HBoxContainer with Label + OptionButton, add to VBoxContainer
- On selection: set `RunData.arena_shape_id`
- Load default from mod config

---

## Config (manifest.json)

```json
"config_schema": {
  "default_arena_shape": { "type": "integer", "default": 0, "minimum": 0, "maximum": 4 },
  "shrinking_min_scale": { "type": "number", "default": 0.4, "minimum": 0.2, "maximum": 0.8 },
  "shrinking_damage_outside": { "type": "integer", "default": 5, "minimum": 0, "maximum": 50 }
}
```

---

## Implementation Order

### Phase 1: Scaffold + Rectangle baseline
1. Create manifest.json, mod_main.gd with all script extension registrations
2. Create ArenaShape base class + RectangleShape
3. Create run_data.gd extension (arena_shape_id, arena_shape fields)
4. Create zone_service.gd extension (setup shape in set_current_zone)
5. **Test:** Game behaves identically with mod enabled

### Phase 2: Circle shape (proves the architecture)
1. Implement CircleShape with all methods
2. Create unit.gd extension (shape-aware clamping)
3. Create my_tile_map.gd extension (shape-aware fill + outline)
4. Create my_tile_map_limits.gd extension (polygon collision)
5. Create entity_spawner.gd extension (shape-aware spawning)
6. Create main.gd extension (outline drawing)
7. **Test:** Hardcode circle, verify clamping/spawning/visuals/collision

### Phase 3: UI integration
1. Create difficulty_selection.gd extension with OptionButton
2. Wire config loading in mod_main.gd
3. Add translations
4. **Test:** Select circle from UI, play a run

### Phase 4: Hexagon + Diamond
1. Implement HexagonShape and DiamondShape
2. Both reuse Phase 2 extension infrastructure (no new extensions needed)
3. **Test:** Each shape -- spawning at vertices, clamping at edges

### Phase 5: Closing Storm shape
1. Implement ShrinkingShape with update() method
2. Add timer logic in main.gd extension
3. Add danger zone visual overlay
4. Handle dynamic wall rebuilding (0.5s timer)
5. Optional: damage-outside-zone mechanic
6. **Test:** Arena shrinks, entities pushed inward, walls contract

---

## Key Files to Read/Modify

| Base Game File | What to Override |
|---|---|
| entities/units/unit/unit.gd:164-211 | Position clamping in `_integrate_forces` |
| singletons/zone_service.gd | `set_current_zone`, `get_rand_pos`, `get_rand_pos_in_area` |
| global/my_tile_map_limits.gd | `init()` -- collision wall creation |
| global/my_tile_map.gd | `init()` -- tile fill + outline |
| global/entity_spawner.gd | `get_spawn_pos_in_area` -- edge spawning |
| main.gd:146-155 | Arena initialization sequence |
| HoardMode difficulty_selection.gd | Reference pattern for UI |

---

## Edge Cases & Compatibility Notes

- **Projectiles**: Use camera rect (always rectangular, larger than arena) for cleanup -- no change needed
- **Camera bounds**: Remain rectangular -- no change needed
- **Map size modifier**: Applied before `set_current_zone`, so shape auto-scales
- **HoardMode compatibility**: Both mods extend same scripts; ModLoader chains extensions via `._ready()` calls. No conflicts as long as both call parent methods
- **Performance**: Shape containment checks are O(1) -- circle is one `length_squared()`, hex/diamond are a few comparisons. Fast enough for per-frame per-entity calls
- **Shrinking wall rebuild**: Every 0.5s via timer, not per-frame. Clamping in `_integrate_forces` is the primary containment
- **Tiles outside shape**: Left empty (void visible beyond boundary). Could fill all + darken overlay later as polish

---

## Verification

1. Enable mod, select Rectangle -- game should be identical to vanilla
2. Select Circle -- arena is round, enemies spawn at edges of circle, player can't leave circle, tiles fill a circle, outline is circular
3. Select Hexagon/Diamond -- same checks with respective shapes
4. Select Closing Storm -- arena starts full-size, shrinks during wave, entities pushed inward
5. Test with HoardMode enabled simultaneously -- both mods work together
6. Test save/load mid-run -- arena shape persists
7. Test map_size modifier -- shapes scale correctly
