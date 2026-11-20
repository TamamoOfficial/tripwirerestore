package com.tripwirerestore.mixin;

import com.llamalad7.mixinextras.injector.ModifyExpressionValue;
import net.minecraft.world.level.block.TripWireHookBlock;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/**
 * 还原 MC-129055：让 NeoForge 的 "防刷线" 守卫失效，恢复原版行为。
 *
 * <p>原版 1.21.1 的 {@code calculateState} 尾部是无条件回写：
 * <pre>
 *   if (blockstate2 != null) {
 *       level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);
 *       if (!level.getBlockState(pos).isAir()) { }   // 空壳，什么都不做
 *   }
 * </pre>
 *
 * <p>Forge/NeoForge 把那个空壳 if 提到了 setBlock 之前当成守卫：
 * <pre>
 *   if (blockstate2 != null) {
 *       if (!level.getBlockState(pos).isAir()) {     // &lt;-- FORGE: fix MC-129055
 *           level.setBlock(pos, blockstate2.trySetValue(ATTACHED, flag2), 3);
 *       }
 *   }
 * </pre>
 *
 * <p>于是「线已被剪掉（变成空气）→ 钩子不再把线写回来」→ 刷线机失效。
 *
 * <p>本 mixin 把 {@code isAir()} 的返回值改成 {@code false}，守卫条件恒为真，
 * 回写重新变成无条件 —— 与 1.21.1 原版逐字节等价。
 * （已确认 21.1.265 的 {@code calculateState} 中 {@code isAir()} 只有这一个调用点，
 * 因此不需要 ordinal，也不会误伤其它分支。）
 */
@Mixin(TripWireHookBlock.class)
public abstract class TripWireHookBlockMixin {

    @ModifyExpressionValue(
            method = "calculateState",
            at = @At(
                    value = "INVOKE",
                    target = "Lnet/minecraft/world/level/block/state/BlockState;isAir()Z"
            )
    )
    private static boolean tripwirerestore$disableMc129055Patch(boolean original) {
        return false;
    }
}
