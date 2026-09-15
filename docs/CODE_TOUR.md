# Esoterica code tour

A file-by-file and function-by-function walkthrough of the codebase as of the
uncommitted animation work (September 2026). Read this alongside the source.
Line numbers refer to the current working tree.

Toolchain: Odin `dev-2024-12-nightly` plus the vendored raylib bindings.
Build with `odin build .` from the repo root and run the resulting binary from
the repo root, because every asset path is relative to the working directory.

---

## Mental model in one paragraph

The world is a 16x16 grid. Each cell has a ground tile id, a foreground object
id, and a derived `walkable` flag. The player lives in **screen space** (an
`rl.Vector2` in pixels) and is converted to grid space only when a collision
check or a draw-order decision needs it. Drawing happens in painter's order,
row by row, column by column, which is correct for a 2:1 dimetric projection
because a cell at `(x, y)` is always in front of any cell with a smaller
`x + y`. The player is inserted into that walk when the loop reaches the cell
the player currently stands on, so foreground objects in cells behind the
player draw before it and ones in front draw after it.

## Frame loop

Every frame in `main` does the following in order:

1. Clear and draw the static full-screen background texture (not affected by camera).
2. Toggle debug on F1.
3. Read WASD into `player_vel`, pick the run or idle animation, propose a new
   position, convert it to grid space, and accept it only if it is in bounds
   and the target cell is walkable.
4. Advance the current animation's frame timer.
5. Build a `Camera2D` centered on the player, zoomed so that 1080 virtual
   pixels always fill the window height.
6. `draw_bg` walks the ground layer. `draw_fg` walks the foreground layer and
   draws the player in the correct spot.
7. Print position on P when debugging.

There is no fixed timestep and no separation of update from render. At this
size that is fine.

## Coordinate systems

There are three, and mixing them up is the most likely source of future bugs.

| Space  | Unit  | Origin | Who uses it |
|--------|-------|--------|-------------|
| Grid   | cells (float) | cell `(0,0)` | level data, collision, draw order |
| World  | pixels | grid `(0,0)` projected | `player_pos`, camera target, all `DrawTexture*` calls inside `BeginMode2D` |
| Screen | pixels | window top-left | only the background texture and the camera offset |

The projection from grid to world is the classic 2:1 dimetric transform with
`TileWidth = 256`:

```
world.x = (gx - gy) * 128
world.y = (gx + gy) * 64
```

so a tile's diamond footprint is 256 wide by 128 tall. The inverse is in
`iso.iso_to_grid`.

---

## `main.odin` (208 lines)

Owns all program state as locals inside `main`. There is no global game
struct. `state.odin` exists but is empty, which suggests that was the plan.

### Constants and globals

- `PixelWindowHeight :: 1080` (line 14). Virtual vertical resolution. The
  camera zoom is `screen_height / 1080`, so the game renders identically on any
  window height and letterboxes horizontally by showing more or less world.
- `PlayerSpeed :: 250` (line 15). Pixels per second in world space. Currently
  only applied to the A key; see the bug list.
- `TileWidth :: 256` (line 18). Pixel width of a tile texture. Every
  projection is derived from this.
- `DebugAllowed :: true`, `Debugging := true` (lines 20 to 21). `DebugAllowed`
  is never read. `Debugging` gates the red dot under the player and the P
  keypress printout.

### `out_of_bounds(player_grid_pos, level_width) -> bool` (line 23)

Returns true when the grid position is outside `[0, level_width]` on either
axis. Uses `<=` on the upper bound, so a position exactly equal to
`level_width` is considered in bounds, and `tile_collision` will then index one
past the end of the array. Also assumes the level is square: only one
dimension is passed in.

### `tile_collision(player_grid_pos, level) -> bool` (line 32)

Truncates the float grid position to ints and returns the collision map value.
No bounds check of its own; relies on `out_of_bounds` being called first, which
`main` does. Note the truncation: `cast(int)` on a negative float like `-0.3`
gives `0`, so a player slightly past the left edge in grid space reads as being
in column 0. `out_of_bounds` catches this case because it compares the float.

### `generate_collision_map(level: ^Level)` (line 36)

Allocates a 2D dynamic bool array sized `[len(tile_map[0])][len(tile_map)]`
(note the transposed sizing, harmless for a square level) and fills it:

```
blocked = ground_tile_id <= 0 || foreground_id > 0
```

So empty ground is a hole, and anything in the foreground layer is solid.
There is no way to have a walk-through foreground decoration yet.

### `main()` (line 51)

In order:

- **Tracking allocator** (lines 52 to 68). Wraps `context.allocator` and
  prints every leaked allocation and bad free at exit. Note this is inside its
  own block, so the `defer` fires when the block ends, not when `main` ends.
  The `context.allocator` assignment also does not escape the block. As
  written the tracker only covers those 16 lines and reports nothing useful.
  Move the block contents to `main`'s top level to make it work.
- **Window** (lines 75 to 77). 1280x720, resizable, target 500 FPS.
- **Animations** (lines 79 to 93). Two `Animation` values. Both currently load
  `run.png` and are named `.Run`. `player_idle` should load `idle.png`
  (256x64, 4 frames) and be named `.Idle`.
- **Level load** (lines 97 to 109). Reads `levels/level.json` into the temp
  allocator and unmarshals straight into `Level`. Field names in the JSON
  match the struct field names exactly. If the file is missing, `level` stays
  zeroed and `generate_collision_map` will index `tile_map[0]` on an empty
  slice and crash. `player_pos` in JSON is a grid coordinate and is projected
  to world space on line 112.
- **Movement block** (lines 128 to 173). Documented in the frame loop above.
  The commented line 159 is the intended velocity normalization.
- **Camera and draw** (lines 175 to 186). `BeginMode2D` is opened but
  `EndMode2D` is never called. raylib tolerates this because `EndDrawing`
  resets the matrix stack, but it is worth fixing.
- **Teardown** (lines 203 to 207). `CloseWindow`, free temp allocator, unload
  ground tiles. Foreground textures, both animation textures, and the
  background texture are never unloaded.

---

## `draw.odin` (94 lines)

### `draw_grid_texture(texture, x, y)` (line 7)

Projects grid cell `(x, y)` to world space and draws the texture so that the
**bottom `TileWidth` pixels** of the image sit on the cell's diamond. The
origin argument `{0, texture.height - TileWidth}` is what makes a 256x512 bush
or a 256x768 turret stand on the tile rather than hang below it. This works
because every sprite is exactly 256 wide and its tile footprint is always the
bottom 256x256 square of the image. That convention is undocumented in the
code and worth a comment.

The projection here is a duplicate of `iso.grid_to_iso` using integer math.
See refactor candidates.

### `draw_bg(level)` (line 28)

Iterates rows then columns, lazy-loads the tile texture through `load_tile`,
and draws it. `i` is treated as grid x and `j` as grid y, which means the
outer JSON array is x and the inner array is y. When you edit `level.json`,
each visual row of numbers is a column of the world going down and to the right.

### `draw_fg(level, player_pos, a, flip, debug)` (line 43)

Same walk as `draw_bg`. Before drawing each cell's foreground object it checks
whether the player's truncated grid position equals `(i, j)` and if so draws
the player first. This gives correct occlusion for a single entity with a
single-cell footprint. It recomputes `iso_to_grid` for the player on every one
of the 256 cells; the result should be computed once outside the loop.

### `draw_player(pos, a, flip, debug)` (line 65)

Slices the horizontal sprite strip into `num_frames` equal columns, picks the
current one, and flips by negating the source width (a raylib idiom). The
destination origin is `{width/2, height}`, so `pos` is the sprite's bottom
center, which is the point that should sit on the ground. The red debug dot is
drawn at that same point.

---

## `iso/iso.odin` (16 lines)

Separate package so it has no access to `TileWidth` and takes it as a
parameter. Takes and returns raylib vectors, so it is not actually
engine-agnostic despite the package boundary.

### `grid_to_iso(x_grid, y_grid, tile_width) -> Vector2` (line 5)

The forward projection. Output is the top vertex of the cell's diamond, not
its center.

### `iso_to_grid(x_iso, y_iso, tile_width) -> Vector2` (line 9)

The inverse. The `-0.5, +0.5` adjustment on line 15 is a fudge to shift the
result so that truncation lands in the visually correct cell. The comment
explains the intent but the asymmetry (minus on x, plus on y) is not obvious;
it is compensating for `grid_to_iso` returning the top vertex rather than the
center. If `grid_to_iso` returned the center instead, this offset would go away.

---

## `tile.odin` (55 lines) and `foreground.odin` (51 lines)

These two files are the same 50 lines with the names changed. Each holds:

- An enum of ids (`Tile`, `Foreground`) whose integer values match the numbers
  in `level.json`. `Empty = 0` in both.
- A parallel enumerated array of texture paths.
- A file-private enumerated array of loaded `Texture2D`, where `id == 0` means
  not yet loaded. raylib guarantees a real texture never has id 0.
- `load_*` which lazy-loads on first request and returns the cached handle.
- `unload_*` for one entry and `unload_all_*` / `unload_tiles` for all.

The `#partial` initializer on the cache array is unnecessary since the zero
value already has `id = 0`.

Note the assets on disk that have no enum entry: `turret1.png`, `wood1.png`,
and every `*_i.png` inverted variant.

---

## `level.odin` (10 lines)

```
Level :: struct {
    player_pos:     rl.Vector2,          // grid coordinates
    tile_map:       [][]int,             // [x][y] ground ids
    foreground_map: [][]int,             // [x][y] foreground ids
    collision_map:  [dynamic][dynamic]bool, // derived, true = blocked
}
```

`tile_map` and `foreground_map` are allocated by the JSON unmarshaller with
the default allocator, so their inner rows need freeing too. The `defer` in
`main` only deletes the outer slices. `foreground_map` is never freed.

---

## `animation.odin` (30 lines, uncommitted)

### `Animation` struct

A horizontal strip texture, frame count, per-frame duration, and a running
timer. `name` is used by `main` to detect state changes.

### `animation_update(a: ^Animation)`

Accumulates frame time and advances one frame per `frame_length`. Resetting
the timer to 0 rather than subtracting `frame_length` drops the overshoot, so
long frames drift slightly slow. Harmless at 500 FPS, noticeable at 30.

Because `current_anim` in `main` is a **copy** of `player_run` or
`player_idle`, switching animations resets the timer and frame to whatever the
original had, which is always frame 0. That is actually the desired behavior
here, but it is accidental.

---

## `levels/level.json`

Three fields matching `Level`. Both maps are 16 arrays of 16 ints. Ground ids
1 to 4 are the four moss cube variants; 0 is a hole. Foreground ids 1 and 2
are the two bushes. Remember the outer array is x.

---

## Known bugs in the working tree

1. `main.odin:133` sets `player_vel.x = PlayerSpeed` for A while the other
   three directions set magnitude 1. Set all four to unit values and restore
   line 159, guarded against divide by zero when not moving.
2. `main.odin:86` loads `run.png` for idle. Should be `idle.png` with
   `num_frames = 4`, `name = .Idle`.
3. Tracking allocator scope, see above. Reports nothing today.
4. `EndMode2D` missing.
5. `out_of_bounds` upper bound is inclusive.
6. Foreground, animation, and background textures leak at exit. Inner level
   rows leak.
7. `DebugAllowed`, `player_grounded`, `core:math` are unused.
8. The compiled `esoterica` binary is tracked in git. Add a `.gitignore`.

---

## Refactor candidates

These are ordered by how much future work each one unblocks, not by effort.

### 1. Merge `tile.odin` and `foreground.odin` into one generic texture cache

They are identical modulo names. Odin's parametric polymorphism handles this
directly:

```odin
Texture_Cache :: struct($E: typeid) where intrinsics.type_is_enum(E) {
    paths:    [E]cstring,
    textures: [E]rl.Texture2D,
}

cache_get :: proc(c: ^Texture_Cache($E), key: E) -> rl.Texture2D { ... }
cache_unload_all :: proc(c: ^Texture_Cache($E)) { ... }
```

Then `tiles: Texture_Cache(Tile)` and `foreground: Texture_Cache(Foreground)`
are two instances of one implementation. Adding a third layer (props, enemies,
UI) costs an enum and a path table, nothing else. This also fixes the "forgot
to unload foreground" leak because there is one unload path.

### 2. A single `Sprite` or `Drawable` type plus a depth-sorted draw list

Right now the player is special-cased inside the foreground walk. That works
for exactly one entity. Replace it with:

```odin
Drawable :: struct {
    texture: rl.Texture2D,
    source:  rl.Rectangle,   // frame rect, negative width to flip
    world:   rl.Vector2,     // bottom-center anchor in world space
    depth:   f32,            // gx + gy, plus a small bias for ties
}
```

Each frame: clear a `[dynamic]Drawable`, push every foreground object and
every entity, sort by `depth`, draw. Ground tiles can stay in the row walk
because nothing ever sorts between them. This is the change that makes
enemies, projectiles, and the turret possible.

### 3. Move the player into grid space

Store `player_pos` as a grid coordinate and let the camera and draw calls
project it. Movement becomes `pos += dir * speed_in_cells * dt`, WASD maps to
grid axes (or screen axes rotated 45 degrees if you prefer that feel), diagonal
speed is correct for free, and collision is `is_walkable(int(pos.x), int(pos.y))`
with no inverse projection anywhere. `iso_to_grid` then only exists for mouse
picking.

### 4. A `Game_State` struct

Everything that is a local in `main` (player, animations, level, camera,
debug flag) moves into one struct in the currently empty `state.odin`. Pass a
pointer to `update(&gs, dt)` and `draw(&gs)`. This is what makes hot reload,
save and load, and a pause menu straightforward later, and it is a prerequisite
for splitting `main` into readable pieces.

### 5. Make `iso` return cell centers and take a `Tile_Metrics` struct

Have `grid_to_iso` return the diamond center, drop the fudge offset in
`iso_to_grid`, and pass `{width, height}` rather than assuming height is
`width / 2`. Then `draw_grid_texture` can call `iso.grid_to_iso` instead of
carrying its own copy of the math, and elevation becomes a `z * height_step`
subtraction in one place.

### 6. Asset manifest instead of string literals

`TilePath` and `ForegroundPath` hardcode filenames. Once the inverted `_i`
variants are in play, a small table keyed on `(enum, variant)` or a naming
convention like `fmt.ctprintf("textures/%s%s.png", name, suffix)` keeps the
palette swap to one line.

Items 1, 2, and 3 together are a comfortable weekend and leave you with a
codebase that scales to an actual game. Item 4 can be done alongside item 3
since both touch every line of `main`.
