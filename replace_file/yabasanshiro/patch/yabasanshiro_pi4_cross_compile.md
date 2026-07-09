# Yabasanshiro 交叉编译文档 (pi4分支)

## 概述

Yabasanshiro 是一个世嘉土星(Sega Saturn)模拟器，本文档介绍如何在x86_64主机上交叉编译aarch64版本。

## 项目信息

| 项目 | 内容 |
|------|------|
| 源码 | https://github.com/devmiyax/yabause |
| 分支 | pi4 |
| 目标架构 | aarch64 (ARM 64-bit) |
| 目标平台 | RK3326 (Cortex-A35) |
| 补丁 | yabasanshirosa-patch-0010-complete.patch |

## 依赖

### 主机依赖

- gcc-linaro-7.5.0 工具链
- cmake, git, python3 (fonttools)

### 目标依赖 (sysroot)

```
/home/lcdyk/ppsspp_cross/
├── usr/lib/aarch64-linux-gnu/
│   ├── libMali.so → libmali-bifrost-g31-rxp0-gbm.so
│   ├── libEGL.so, libGLESv2.so → libMali.so
│   ├── libgbm.so → libMali.so
│   ├── libSDL2-2.0.so.0
│   ├── libX11.so, libXrandr.so
│   ├── libopenal.so
│   ├── libboost_*.so
│   ├── libasound.so
│   └── librga.so
└── usr/include/
```

## 编译步骤

### 1. 克隆源码

```bash
git clone --recursive https://github.com/devmiyax/yabause -b pi4 yabasanshiro
```

### 2. 应用补丁

```bash
cd yabasanshiro
patch -Np2 < ../patches/yabasanshirosa-patch-0010-complete.patch
```

### 3. 准备host工具

```bash
# bin2c (x86_64)
cp yabasanshiro-build-host/bin2c/bin2c yabause/src/retro_arena/nanogui-sdl/

# m68kmake (x86_64)
mkdir -p ../yabasanshiro-build-host/musashi
cd ../yabasanshiro-build-host/musashi
cmake ../../yabasanshiro/yabause/src/musashi -G "Unix Makefiles"
make -j$(nproc)
```

### 4. 构建

```bash
SYSROOT="/home/lcdyk/ppsspp_cross"
TOOLCHAIN_DIR="/opt/toolchains/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu"

mkdir -p yabasanshiro-build && cd yabasanshiro-build

# 复制m68kmake
mkdir -p src/musashi
cp ../yabasanshiro-build-host/musashi/m68kmake src/musashi/
chmod +x src/musashi/m68kmake
mkdir -p src/m68kmake-prefix/src/m68kmake-stamp
touch src/m68kmake-prefix/src/m68kmake-stamp/m68kmake-{mkdir,download,update,patch,configure,build,done}

# configure
cmake -S ../yabasanshiro/yabause \
    -DCMAKE_RULE_MESSAGES=OFF \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-g++ \
    -DCMAKE_SYSROOT=${SYSROOT} \
    -DCMAKE_C_FLAGS="-march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations -O2" \
    -DCMAKE_CXX_FLAGS="-march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations -O2" \
    -DCMAKE_EXE_LINKER_FLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib/aarch64-linux-gnu -L${SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${SYSROOT}/lib/aarch64-linux-gnu -lEGL -lGLESv2 -lSDL2 -lX11 -lXrandr -lopenal -lboost_system -lboost_filesystem -lboost_date_time -lboost_locale -lz -lm -lpthread -lasound -lrga -lstdc++fs -Wl,--allow-multiple-definition" \
    -DYAB_PORTS=retro_arena \
    -DYAB_WANT_DYNAREC_DEVMIYAX=ON \
    -DYAB_WANT_ARM7=ON \
    -DYAB_WANT_VULKAN=OFF \
    -DUSE_EGL=ON \
    -B .

# 编译
make -j$(nproc)

# 打包
${TOOLCHAIN_DIR}/bin/aarch64-linux-gnu-strip src/retro_arena/yabasanshiro
cp src/retro_arena/yabasanshiro ../yabasanshirosa_pkg/
```

## 补丁说明 (0010-complete)

| 文件 | 修改内容 |
|------|----------|
| `external_libchdr.cmake` | 交叉编译支持 |
| `external_libpng.cmake` | 禁用NEON，交叉编译支持 |
| `external_zlib.cmake` | 交叉编译支持 |
| `InputManager.cpp` | 读取input.cfg配置 |
| `MenuScreen.cpp` | i18n中文菜单 |
| `nanogui-sdl/CMakeLists.txt` | bin2c交叉编译支持 |
| `nanogui-sdl/src/theme.cpp` | CJK字体加载 |
| `threads.h` | u64类型定义 |
| `vidogl.c` | 正方形屏幕显示修复 |
| 其他 | 原始patches (01-06, 08) |

### 原始patches包含情况

| Patch | 状态 | 说明 |
|-------|------|------|
| 01-add-missing-include | ✅ | threads.h |
| 02-low-res-mode | ✅ | 低分辨率模式 |
| 03-removegl3ext | ✅ | 移除GLES3扩展 |
| 04-change-paths | ✅ | 路径修改 |
| 05-savestate-path | ✅ | 存档路径 |
| 06-remove-about | ✅ | 移除关于页面 |
| 07-odroidgoa | ❌ | 跳过（菜单缩放） |
| 08-disable-sh2 | ❌ | pi4分支不适用 |

### 新增修改

| 修改 | 说明 |
|------|------|
| i18n支持 | 根据LANG/LC_ALL自动切换中英文 |
| CJK字体 | 加载wqy-microhei.ttf |
| 正方形屏幕修复 | 修复720x720屏幕的过裁剪问题 |
| input.cfg | 读取/opt/yabasanshiro/input.cfg |

## 设备部署

```bash
cp yabasanshiro /opt/yabasanshiro/
cp wqy-microhei.ttf /opt/yabasanshiro/
cp input.cfg /opt/yabasanshiro/
cp keymapv2.json /opt/yabasanshiro/

# 设置中文locale
sudo locale-gen zh_CN.UTF-8
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
```

## 字体说明

NotoSansCJK 使用 CFF 轮廓，stb_truetype 不支持。使用 WenQuanYi Micro Hei (TrueType格式)。

```bash
# 转换字体
pip install fonttools
python3 -c "
from fontTools.ttLib import TTCollection
ttc = TTCollection('NotoSansCJK-Regular.ttc')
ttc.fonts[0].save('NotoSansCJK-Regular.ttf')
"
```

## 配置文件

| 文件 | 说明 |
|------|------|
| `input.cfg` | 手柄按键映射 (select=12打开菜单) |
| `keymapv2.json` | 模拟器按键映射 |

## 显示逻辑

对于正方形屏幕（720x720），ORIGINAL模式：
```
GlWidth = 720
GlHeight = 720 * 0.7 = 504
originy = (720 - 504) / 2 = 108
```

游戏画面 720x504，垂直居中，上下各108px黑边。
