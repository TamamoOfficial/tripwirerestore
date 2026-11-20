## 中文

还原 NeoForge 1.21.1 上的原版绊线刷线机。

Forge / NeoForge 在 `TripWireHookBlock#calculateState` 里给绊线回写加了一道 `isAir()` 守卫（注释 `// FORGE: fix MC-129055`），让被剪掉的线不再被钩子写回来。本模组把那个布尔值改回原版行为——`isAir()` 恒为 false，守卫恒为真，回写重新变成无条件。

- 改动量：1 个类、1 个方法、1 条字节码指令
- 无网络通道、无配置文件、无新增内容
- 与 carpet-tis-addition 共存验证通过

**安装**：放入 `mods/`。需要 NeoForge 21.1.x + MC 1.21.1。MixinExtras 已由 NeoForge 自带，无需额外安装。

**侧别**：服务端必装，客户端可选（不装可能出现轻微视觉闪烁，不影响产物）。

**不要**与 `tripwiredupe` / `DontCutTripwire` 同装——它们走互斥的另一条路，会互相抵消。

**不要**用于 1.21.2+，那个版本官方已修且修法不同。

---

## English

Restores the vanilla tripwire string duper on NeoForge 1.21.1.

Forge / NeoForge guards the wire write-back in `TripWireHookBlock#calculateState` with an `isAir()` check (commented `// FORGE: fix MC-129055`), so a sheared wire is never written back. This mod flips that single boolean back — `isAir()` is always false, the guard is always true, and the write-back becomes unconditional again.

- Footprint: 1 class, 1 method, 1 bytecode instruction
- No network channels, no config files, no new content
- Verified coexisting with carpet-tis-addition

**Install**: drop into `mods/`. Requires NeoForge 21.1.x + MC 1.21.1. MixinExtras is already bundled with NeoForge — nothing extra needed.

**Sides**: required on the server, optional on clients (without it you may see slight visual flicker; output is unaffected).

**Do NOT** combine with `tripwiredupe` / `DontCutTripwire` — they take the mutually exclusive path and cancel each other out.

**Do not** use on 1.21.2+ — Mojang fixed it there officially, with a different approach.

---

### SHA-256

```
fdc2e615ea565c9cedc00e30d08bb76e1e7418a7888bc50deb350b7d97ec1f56
```
