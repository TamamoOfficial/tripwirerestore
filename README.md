# Tripwire Restore (MC-129055)

[English](README_EN.md) | **中文**

在 **NeoForge 1.21.1** 上还原原版的绊线刷线机（String Duper）。

---

## 这是什么

Forge / NeoForge 在 `TripWireHookBlock#calculateState` 里打了个补丁，给绊线的回写加了一道 `isAir()` 守卫，注释写着 `// FORGE: fix MC-129055`。这一行让「被剪掉的线」不再被钩子写回来，于是原版刷线机失效。

本模组只做一件事：**把那一个布尔值改回原版行为**。

```java
@ModifyExpressionValue(
        method = "calculateState",
        at = @At(value = "INVOKE",
                 target = "Lnet/minecraft/world/level/block/state/BlockState;isAir()Z"))
private static boolean tripwirerestore$disableMc129055Patch(boolean original) {
    return false;
}
```

`isAir()` 恒为 `false` → 守卫条件恒为真 → 回写重新变成无条件，**与 1.21.1 原版逐字节等价**。

---

## 原理

原版 1.21.1 的 `calculateState` 尾部：

```java
if (blockstate2 != null) {
    level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);  // 无条件写回
    if (!level.getBlockState(pos).isAir()) { }                          // 空壳，什么都没做
}
```

Forge / NeoForge 把那个**空壳 `if` 提到了 `setBlock` 之前**当守卫：

```java
if (blockstate2 != null) {
    if (!level.getBlockState(pos).isAir()) {   // <-- FORGE: fix MC-129055
        level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);
    }
}
```

后果：线被剪刀剪掉后位置变成空气，钩子重算时这道守卫拦住了回写，**线不再复活**，刷线机失效。

刷线机依赖的链条是：

1. 剪刀剪断绊线 → 线掉落成线团（string），位置变空气
2. 钩子 `calculateState` 重算 → **原版会把一根 disarmed 的线凭空写回去**
3. 写回的线是 disarmed 的，不会再次触发钩子 → 循环成立

第 2 步就是被 Forge 补丁掐断的地方。

---

## 对原版的影响

| | 本模组 |
|---|---|
| 改动的类 | 1 个（`TripWireHookBlock`） |
| 改动的方法 | 1 个（`calculateState`） |
| 改动的字节码指令 | 1 条（`isAir()` 的返回值） |
| 引入的新类 / 新方块 / 新物品 | 无 |
| 网络通道 | 无 |
| 配置文件 | 无 |

`TripWireBlock#playerWillDestroy` **未改动**。NeoForge 在那里把 `is(Items.SHEARS)` 换成了 `canPerformAction(SHEARS_DISARM)`，行为对原版剪刀完全一致，所以本模组不去碰它（碰了反而会破坏 NeoForge 给模组留的扩展点）。

---

## 安装

把 jar 放进 `mods/` 目录。**需要 NeoForge 21.1.x + Minecraft 1.21.1**。

### 侧别要求

| 拓扑 | 主机 | 来宾 | 说明 |
|---|---|---|---|
| 单人游戏 | ✅ 必装 | — | 内置服务端与客户端同 JVM，共享 `mods/` |
| 客户端作主机（开放到局域网） | ✅ 必装 | ⬜ 可选 | 不装也能用，但可能看到轻微视觉闪烁 |
| 专用服务器（true dedicated） | ✅ 必装 | ⬜ 可选 | 纯服务端即可 |

**为什么客户端不是必需**：`calculateState` 的核心调用点是 `tick(BlockState, ServerLevel, BlockPos, RandomSource)` —— 参数是 `ServerLevel`，客户端根本没有可传的实参。刷线机的全部逻辑都在服务端。

**为什么建议来宾也装**：来宾客户端没装时，它本地的 `calculateState` 仍是被 guard 的版本，对「线该不该复活」的预测是错的，高延迟下可能出现线块短暂缺失再出现的闪烁。这只是视觉现象，**不影响产物**（string 数量完全由服务端决定）。

---

## 兼容性

- **MixinExtras 是必需的**，但 NeoForge 已经自带（`21.1.265` 内嵌 `mixinextras-neoforge-0.5.5.jar` 于 `META-INF/jarjar/`），**不需要额外安装**。
- 与 **carpet-tis-addition** 共存已验证：两者都 mixin `TripWireHookBlock` 且注入成功、无冲突。因为本模组用的是 `@ModifyExpressionValue`（单点改写），不是整方法覆盖，不会挡掉别的 mod 的注入。
- **不要**与以下模组同时安装，它们走的是互斥的另一条路（让剪刀不再破坏绊线，线根本不掉落）：
  - [`tripwiredupe`](https://github.com/chessMCman/tripwiredupe)
  - [`DontCutTripwire`](https://github.com/mcmaidong/DontCutTripwire)

  同时装会互相抵消，什么都刷不出来。

---

## 不要用于 1.21.2+

Mojang 在 **1.21.2** 官方修复了这条链，且修法变了（`playerWillDestroy` 的 flag 从 `4` 改成 `260`，加入 `UPDATE_SUPPRESS_DROPS` 抑制掉落），`calculateState` 也被改写。

在本模组上叠加到 1.21.2+ **不会**还原刷线机，只会造成非预期行为。本模组硬编码针对 1.21.1。

若需要跨版本，参考 [`ccbtweaks`](https://github.com/0x724a/ccb/tree/ccbtweaks/multi-dev) —— 它用 stonecutter 的 `//? if < 1.21.2` 做编译期门控，只在真有该补丁的版本编译进去。

---

## 构建

不依赖 Gradle / 网络，直接调用 JDK：

```bash
./build.sh
```

产物：`build/libs/tripwirerestore-1.21.1-1.0.0.jar`

脚本会自动探测 JDK 与本地 NeoForge 版本（见脚本内注释）。需要 JDK 21+。

---

## 已验证

- 反汇编目标 jar 确认：NeoForge `21.1.265` 的 `calculateState` 中 `isAir()` **仅有一个调用点**，无需 ordinal，不会误伤其它分支
- 字节码：`iconst_0 / ireturn`，返回值确为 `false`
- 运行时使用 mojmap 命名（类中无 `func_` SRG 名），**不需要 refmap**
- 实机加载：`Mixing TripWireHookBlockMixin from tripwirerestore.mixins.json into net.minecraft.world.level.block.TripWireHookBlock`，`InjectionError` / `MixinApplyError` 计数为 0
- 人工游戏内验证通过

---

## 许可

MIT
