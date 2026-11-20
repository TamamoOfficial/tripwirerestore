# Tripwire Restore (MC-129055)

**English** | [中文](README.md)

Restores the vanilla tripwire string duper on **NeoForge 1.21.1**.

---

## What this is

Forge / NeoForge patches `TripWireHookBlock#calculateState` to guard the wire write-back with an `isAir()` check, commented `// FORGE: fix MC-129055`. That one line stops the hook from writing a sheared wire back, which breaks the vanilla string farm.

This mod does exactly one thing: **flip that single boolean back to vanilla behaviour**.

```java
@ModifyExpressionValue(
        method = "calculateState",
        at = @At(value = "INVOKE",
                 target = "Lnet/minecraft/world/level/block/state/BlockState;isAir()Z"))
private static boolean tripwirerestore$disableMc129055Patch(boolean original) {
    return false;
}
```

`isAir()` is now always `false` → the guard is always true → the write-back becomes unconditional again, **byte-for-byte equivalent to vanilla 1.21.1**.

---

## How it works

Vanilla 1.21.1 tail of `calculateState`:

```java
if (blockstate2 != null) {
    level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);  // unconditional write-back
    if (!level.getBlockState(pos).isAir()) { }                          // empty shell, does nothing
}
```

Forge / NeoForge **hoisted that empty `if` above the `setBlock`** and turned it into a guard:

```java
if (blockstate2 != null) {
    if (!level.getBlockState(pos).isAir()) {   // <-- FORGE: fix MC-129055
        level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);
    }
}
```

Result: once the wire is sheared, the position becomes air, the guard blocks the write-back, and **the wire no longer respawns** — the string farm dies.

The chain the farm depends on:

1. Shear the tripwire → the wire drops as string, the position becomes air
2. The hook re-runs `calculateState` → **vanilla writes a disarmed wire back out of thin air**
3. That written-back wire is disarmed, so it won't re-trigger the hook → the loop holds

Step 2 is precisely what the Forge patch severs.

---

## Footprint

| | This mod |
|---|---|
| Classes touched | 1 (`TripWireHookBlock`) |
| Methods touched | 1 (`calculateState`) |
| Bytecode instructions changed | 1 (the return value of `isAir()`) |
| New classes / blocks / items | none |
| Network channels | none |
| Config files | none |

`TripWireBlock#playerWillDestroy` is **left untouched**. NeoForge changed `is(Items.SHEARS)` to `canPerformAction(SHEARS_DISARM)` there, which behaves identically for vanilla shears — so this mod stays away from it. Overwriting it would only delete an extension point NeoForge provides to other mods.

---

## Install

Drop the jar into `mods/`. **Requires NeoForge 21.1.x + Minecraft 1.21.1.**

### Side requirements

| Setup | Host | Guests | Notes |
|---|---|---|---|
| Singleplayer | ✅ required | — | Integrated server shares the same JVM and `mods/` |
| Client as host (LAN) | ✅ required | ⬜ optional | Works without it, but may show slight visual flicker |
| Dedicated server | ✅ required | ⬜ optional | Server-side only is enough |

**Why clients don't need it**: the core call site is `tick(BlockState, ServerLevel, BlockPos, RandomSource)` — the parameter is `ServerLevel`, so a client has nothing to pass in. The entire farm logic lives on the server.

**Why guests should still install it**: without it, a guest's local `calculateState` is still the guarded version, so its prediction of "should this wire respawn" is wrong. On high latency that can show up as the wire block briefly vanishing and reappearing. Purely visual — **it does not affect output** (string count is decided entirely by the server).

---

## Compatibility

- **MixinExtras is required but already bundled** — NeoForge `21.1.265` ships `mixinextras-neoforge-0.5.5.jar` inside `META-INF/jarjar/`. **No extra install needed.**
- Verified coexisting with **carpet-tis-addition**: both mixin `TripWireHookBlock` and both inject successfully with no conflict. This is because the mod uses `@ModifyExpressionValue` (single-point rewrite) rather than replacing the whole method, so it never blocks other mods' injections.
- **Do NOT** install alongside these — they take the mutually exclusive path (stop shears from destroying the tripwire at all, so the wire never drops):
  - [`tripwiredupe`](https://github.com/chessMCman/tripwiredupe)
  - [`DontCutTripwire](https://github.com/mcmaidong/DontCutTripwire)

  Together they cancel each other out and nothing duplicates.

---

## Do not use on 1.21.2+

Mojang fixed this chain officially in **1.21.2**, and the fix is different: `playerWillDestroy`'s flag changed from `4` to `260` (adding `UPDATE_SUPPRESS_DROPS`), and `calculateState` was rewritten.

Carrying this mod onto 1.21.2+ will **not** restore the farm — it will only cause unexpected behaviour. This mod is hard-targeted at 1.21.1.

If you need multi-version support, see [`ccbtweaks`](https://github.com/0x724a/ccb/tree/ccbtweaks/multi-dev) — it uses stonecutter `//? if < 1.21.2` compile-time gating so the mixin only compiles for versions that actually carry the patch.

---

## Build

No Gradle, no network — drives the JDK directly:

```bash
./build.sh
```

Output: `build/libs/tripwirerestore-1.21.1-1.0.0.jar`

The script auto-detects the JDK and the local NeoForge version (see comments inside). Requires JDK 21+.

---

## Verified

- Disassembled the target jar: in NeoForge `21.1.265`'s `calculateState`, `isAir()` has **exactly one call site** — no ordinal needed, no risk of hitting an unrelated branch
- Bytecode: `iconst_0 / ireturn` — the return value is confirmed `false`
- Runtime uses mojmap names (no `func_` SRG names in the class), so **no refmap is required**
- Live load: `Mixing TripWireHookBlockMixin from tripwirerestore.mixins.json into net.minecraft.world.level.block.TripWireHookBlock`, with `InjectionError` / `MixinApplyError` count at 0
- Verified in-game by hand

---

## License

MIT
