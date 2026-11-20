package com.tripwirerestore;

import net.neoforged.fml.common.Mod;

/**
 * 空壳入口类。本模组的全部行为都在 mixin 里，
 * 这个类只用于让 FML 识别并加载 mod 元数据。
 */
@Mod(TripwireRestore.MODID)
public final class TripwireRestore {
    public static final String MODID = "tripwirerestore";

    public TripwireRestore() {
        // 无逻辑
    }
}
