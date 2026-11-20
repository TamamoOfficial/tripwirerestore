#!/usr/bin/env bash
# 直接调用 JDK 编译 + 打包，不依赖 Gradle / 网络。
#
# 自动探测：
#   - JDK：优先 JAVA_HOME，其次 PATH，最后扫常见安装目录（要求 21+）
#   - NeoForge：扫 .minecraft/libraries/net/neoforged/neoforge/ 取最高版本
#   - MixinExtras：从 NeoForge universal jar 的 META-INF/jarjar/ 里解出来
#
# 可用环境变量覆盖：MC_DIR、JDK_HOME
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
W() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

# ---------- 定位 .minecraft ----------
MC="${MC_DIR:-F:/MC Launcher/.minecraft}"
[ -d "$MC/libraries" ] || { echo "找不到 .minecraft: $MC（可用 MC_DIR 覆盖）" >&2; exit 1; }

# ---------- 定位 NeoForge（取最高版本）----------
NFROOT="$MC/libraries/net/neoforged/neoforge"
[ -d "$NFROOT" ] || { echo "找不到 NeoForge: $NFROOT" >&2; exit 1; }
NFVER="$(ls "$NFROOT" | sort -V | tail -1)"
NF="$NFROOT/$NFVER/neoforge-$NFVER-client.jar"
NFU="$NFROOT/$NFVER/neoforge-$NFVER-universal.jar"
[ -f "$NF" ] || { echo "找不到 client jar: $NF" >&2; exit 1; }
[ -f "$NFU" ] || { echo "找不到 universal jar: $NFU" >&2; exit 1; }

# FML loader 版本随 NeoForge 变化，取最高
LOADERBASE="$MC/libraries/net/neoforged/fancymodloader/loader"
LOADERVER="$(ls "$LOADERBASE" | sort -V | tail -1)"
LOADER="$LOADERBASE/$LOADERVER/loader-$LOADERVER.jar"

# Mixin：优先用 NeoForge 版本 json 里声明的那个，找不到再退回最高版本
MIXINBASE="$MC/libraries/net/fabricmc/sponge-mixin"
NFJSON="$MC/versions/neoforge-$NFVER/neoforge-$NFVER.json"
MIXINVER=""
if [ -f "$NFJSON" ]; then
  MIXINVER="$(grep -o 'net\.fabricmc:sponge-mixin:[^"]*' "$NFJSON" | head -1 | sed 's/.*sponge-mixin://')"
fi
[ -n "$MIXINVER" ] && [ -d "$MIXINBASE/$MIXINVER" ] || MIXINVER="$(ls "$MIXINBASE" | sort -V | tail -1)"
MIXIN="$MIXINBASE/$MIXINVER/sponge-mixin-$MIXINVER.jar"

# Dist 枚举所在
DIST_API="$MC/libraries/net/neoforged/mergetool/2.0.0/mergetool-2.0.0-api.jar"

echo "==> NeoForge $NFVER / FML $LOADERVER / Mixin $MIXINVER"

# ---------- 定位 JDK（要求 21+）----------
try_jdk() {
  local d="$1"
  [ -x "$d/bin/javac.exe" ] || [ -x "$d/bin/javac" ] || return 1
  local v
  v="$("$d/bin/javac" -version 2>&1 | sed -E 's/javac ([0-9]+).*/\1/')"
  [ -n "$v" ] && [ "$v" -ge 21 ] 2>/dev/null && echo "$d"
}

JDK=""
if [ -n "${JDK_HOME:-}" ]; then
  JDK="$(try_jdk "$JDK_HOME")" || true
fi
if [ -z "$JDK" ] && [ -n "${JAVA_HOME:-}" ]; then
  JDK="$(try_jdk "$JAVA_HOME")" || true
fi
if [ -z "$JDK" ] && command -v javac >/dev/null 2>&1; then
  JDK="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
  JDK="$(try_jdk "$JDK")" || JDK=""
fi
if [ -z "$JDK" ]; then
  for base in "/c/Program Files/Java" "/c/Program Files/Zulu" "/c/Program Files/Eclipse Adoptium"; do
    [ -d "$base" ] || continue
    for d in "$base"/*/; do
      d="${d%/}"
      cand="$(try_jdk "$d")" && { JDK="$cand"; break; }
    done
    [ -n "$JDK" ] && break
  done
fi
[ -n "$JDK" ] || { echo "找不到 JDK 21+（可用 JDK_HOME 指定）" >&2; exit 1; }
echo "==> JDK: $JDK"

JAVAC="$JDK/bin/javac"
JAR="$JDK/bin/jar"
[ -x "$JAVAC.exe" ] && JAVAC="$JAVAC.exe" && JAR="$JAR.exe"

# ---------- 解出 MixinExtras ----------
EXTRAS_DIR="$ROOT/build/deps"
mkdir -p "$EXTRAS_DIR"
EXTRAS="$EXTRAS_DIR/mixinextras-neoforge.jar"
if [ ! -f "$EXTRAS" ]; then
  echo "==> 从 NeoForge 解出 MixinExtras"
  unzip -o -q "$NFU" "META-INF/jarjar/mixinextras-*.jar" -d "$EXTRAS_DIR/tmp"
  found="$(find "$EXTRAS_DIR/tmp" -name 'mixinextras-*.jar' | head -1)"
  [ -n "$found" ] || { echo "universal jar 里没有 MixinExtras" >&2; exit 1; }
  mv "$found" "$EXTRAS"
  rm -rf "$EXTRAS_DIR/tmp"
fi

for f in "$NF" "$LOADER" "$MIXIN" "$DIST_API" "$EXTRAS"; do
  [ -f "$f" ] || { echo "缺少依赖: $f" >&2; exit 1; }
done

CP="$(W "$NF");$(W "$LOADER");$(W "$MIXIN");$(W "$DIST_API");$(W "$EXTRAS")"

OUT="$ROOT/build/classes"
DISTDIR="$ROOT/build/libs"
rm -rf "$OUT" "$DISTDIR"
mkdir -p "$OUT" "$DISTDIR"

# ---------- 版本号取自 TOML ----------
MODVER="$(grep -E '^version[[:space:]]*=' "$ROOT/src/main/resources/META-INF/neoforge.mods.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
[ -n "$MODVER" ] || MODVER="1.0.0"

echo "==> 编译 (release 21)"
cd "$ROOT"
find "src/main/java" -name '*.java' -print0 > build/sources0.txt
: > build/sources.txt
while IFS= read -r -d '' f; do W "$f" >> build/sources.txt; done < build/sources0.txt

"$JAVAC" --release 21 -proc:none -encoding UTF-8 \
  -cp "$CP" -d "$(W "$OUT")" "@$(W "$ROOT/build/sources.txt")"

echo "==> 拷贝资源"
cp -r "$ROOT/src/main/resources/." "$OUT/"

echo "==> 打包"
JARNAME="tripwirerestore-1.21.1-$MODVER.jar"
"$JAR" --create --file "$(W "$DISTDIR/$JARNAME")" -C "$(W "$OUT")" .

echo "==> 产物: $DISTDIR/$JARNAME"
ls -l "$DISTDIR/$JARNAME"
