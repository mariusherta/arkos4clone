# Flycast 2022 aarch64 交叉编译指南

## 概述

本文档描述如何在 x86_64 Linux 主机上交叉编译 Flycast 2022 版本，目标平台为 ARM64 (aarch64)。

- **commit**: `aa97a6d64 pvr: last naomi2 poly was ignored in some cases`
- **输出**: 20.4MB 可执行文件
- **依赖**: SDL2, libgomp

## 工具链

### 交叉编译器

使用 ARM 官方 GCC 9.2 aarch64 工具链：

```
/opt/toolchains/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/
```

工具链前缀：`aarch64-none-linux-gnu-`

### 系统根目录 (sysroot)

```
/opt/sysroot/
```

## Sysroot 操作

### 问题描述

sysroot 中的头文件采用 multiarch 目录结构，但编译器期望标准路径：

```
/opt/sysroot/usr/include/aarch64-linux-gnu/bits/   # 实际位置
/opt/sysroot/usr/include/bits/                      # 编译器期望位置
```

### 解决方案

创建符号链接将 multiarch 目录映射到标准路径：

```bash
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/bits /opt/sysroot/usr/include/bits
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/sys  /opt/sysroot/usr/include/sys
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/gnu  /opt/sysroot/usr/include/gnu
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/asm  /opt/sysroot/usr/include/asm
```

### SDL2 CMake 配置

sysroot 中没有 SDL2 的 CMake 配置文件，需要手动创建：

```bash
mkdir -p /tmp/sdl2-aarch64/lib/cmake/SDL2
cat > /tmp/sdl2-aarch64/lib/cmake/SDL2/SDL2Config.cmake << 'EOF'
set(SDL2_FOUND ON)
set(SDL2_INCLUDE_DIRS "/opt/sysroot/usr/include/SDL2")
set(SDL2_LIBRARIES "/opt/sysroot/usr/lib/aarch64-linux-gnu/libSDL2.so")
set(SDL2_VERSION "2.24.0")
if(NOT TARGET SDL2::SDL2)
    add_library(SDL2::SDL2 SHARED IMPORTED)
    set_target_properties(SDL2::SDL2 PROPERTIES
        IMPORTED_LOCATION "/opt/sysroot/usr/lib/aarch64-linux-gnu/libSDL2.so"
        INTERFACE_INCLUDE_DIRECTORIES "/opt/sysroot/usr/include/SDL2"
    )
endif()
EOF
```

**注意**: 如果 sysroot 中有 `/opt/sysroot/usr/lib/aarch64-linux-gnu/cmake/SDL2/sdl2-config.cmake`，需要备份并移除，否则会覆盖我们的配置：

```bash
sudo mv /opt/sysroot/usr/lib/aarch64-linux-gnu/cmake/SDL2/sdl2-config.cmake \
        /opt/sysroot/usr/lib/aarch64-linux-gnu/cmake/SDL2/sdl2-config.cmake.bak
```

## 工具链文件

`aarch64-toolchain.cmake`：

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(TOOLCHAIN_PREFIX /opt/toolchains/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-)

set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_AR ${TOOLCHAIN_PREFIX}ar)
set(CMAKE_RANLIB ${TOOLCHAIN_PREFIX}ranlib)
set(CMAKE_STRIP ${TOOLCHAIN_PREFIX}strip)

set(CMAKE_SYSROOT /opt/sysroot)

set(CMAKE_FIND_ROOT_PATH /opt/sysroot)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_EXE_LINKER_FLAGS "-L/opt/sysroot/usr/lib/aarch64-linux-gnu -L/opt/sysroot/lib/aarch64-linux-gnu -B/opt/sysroot/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/opt/sysroot/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/opt/sysroot/lib/aarch64-linux-gnu")
set(CMAKE_SHARED_LINKER_FLAGS "-L/opt/sysroot/usr/lib/aarch64-linux-gnu -L/opt/sysroot/lib/aarch64-linux-gnu -B/opt/sysroot/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/opt/sysroot/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/opt/sysroot/lib/aarch64-linux-gnu")
```

### 关键参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| `CMAKE_SYSTEM_PROCESSOR` | aarch64 | 目标处理器架构 |
| `CMAKE_SYSROOT` | /opt/sysroot | 目标系统根目录 |
| `-B` 链接器标志 | /opt/sysroot/usr/lib/aarch64-linux-gnu | 指定 crt1.o, crti.o 等 C 运行时文件路径 |

## 编译选项

### CMake 选项

| 选项 | 值 | 说明 |
|------|-----|------|
| `CMAKE_BUILD_TYPE` | Release | 发布版本 |
| `USE_GLES` | ON | 使用 OpenGL ES 3 |
| `USE_GLES2` | OFF | 不使用 OpenGL ES 2 |
| `USE_VULKAN` | OFF | 不使用 Vulkan |
| `USE_OPENMP` | ON | 启用 OpenMP |
| `USE_HOST_LIBZIP` | ON | 使用主机 libzip |
| `CMAKE_POLICY_VERSION_MINIMUM` | 3.5 | 兼容旧版 CMake 策略 |

## 编译步骤

### 1. 准备 sysroot

从 ArkOS 镜像提取库文件：

```bash
# 挂载 ArkOS 镜像
sudo mount -o loop,ro,offset=$((262144*512)) ArkOS4Clone.img /tmp/arkos-mount

# 创建 multiarch 符号链接
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/bits /opt/sysroot/usr/include/bits
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/sys  /opt/sysroot/usr/include/sys
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/gnu  /opt/sysroot/usr/include/gnu
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/asm  /opt/sysroot/usr/include/asm

# 备份 sysroot 中的 SDL2 配置
sudo mv /opt/sysroot/usr/lib/aarch64-linux-gnu/cmake/SDL2/sdl2-config.cmake \
        /opt/sysroot/usr/lib/aarch64-linux-gnu/cmake/SDL2/sdl2-config.cmake.bak

# 卸载镜像
sudo umount /tmp/arkos-mount
```

### 2. 创建 SDL2 CMake 配置

```bash
mkdir -p /tmp/sdl2-aarch64/lib/cmake/SDL2
cat > /tmp/sdl2-aarch64/lib/cmake/SDL2/SDL2Config.cmake << 'EOF'
set(SDL2_FOUND ON)
set(SDL2_INCLUDE_DIRS "/opt/sysroot/usr/include/SDL2")
set(SDL2_LIBRARIES "/opt/sysroot/usr/lib/aarch64-linux-gnu/libSDL2.so")
set(SDL2_VERSION "2.24.0")
if(NOT TARGET SDL2::SDL2)
    add_library(SDL2::SDL2 SHARED IMPORTED)
    set_target_properties(SDL2::SDL2 PROPERTIES
        IMPORTED_LOCATION "/opt/sysroot/usr/lib/aarch64-linux-gnu/libSDL2.so"
        INTERFACE_INCLUDE_DIRECTORIES "/opt/sysroot/usr/include/SDL2"
    )
endif()
EOF
```

### 3. 应用补丁

```bash
cd ~/flycast2022
git apply flycast2022-aarch64-chinese-savestate-720x720.patch
```

### 4. 配置 CMake

```bash
cmake -B build-aarch64 \
    -DCMAKE_TOOLCHAIN_FILE=aarch64-toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_GLES=ON \
    -DUSE_GLES2=OFF \
    -DUSE_VULKAN=OFF \
    -DUSE_OPENMP=ON \
    -DUSE_HOST_LIBZIP=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DSDL2_DIR=/tmp/sdl2-aarch64/lib/cmake/SDL2
```

### 5. 编译

```bash
make -C build-aarch64 -j$(nproc)
```

### 6. 输出文件

```
build-aarch64/flycast
```

## 链接库

### 运行时依赖（来自 sysroot）

| 库 | 路径 | 用途 |
|----|------|------|
| libSDL2-2.0.so.0 | `/opt/sysroot/usr/lib/aarch64-linux-gnu/` | 输入/音频/窗口管理 |
| libgomp.so.1 | 工具链提供 | OpenMP 并行计算 |
| libstdc++.so.6 | 工具链提供 | C++ 标准库 |
| libpthread.so.0 | `/opt/sysroot/lib/aarch64-linux-gnu/` | 线程 |
| libdl.so.2 | `/opt/sysroot/lib/aarch64-linux-gnu/` | 动态链接 |
| libc.so.6 | `/opt/sysroot/lib/aarch64-linux-gnu/` | C 标准库 |
| libgcc_s.so.1 | 工具链提供 | GCC 运行时 |

### 链接器标志

```
-L/opt/sysroot/usr/lib/aarch64-linux-gnu
-L/opt/sysroot/lib/aarch64-linux-gnu
-B/opt/sysroot/usr/lib/aarch64-linux-gnu
-Wl,-rpath-link,/opt/sysroot/usr/lib/aarch64-linux-gnu
-Wl,-rpath-link,/opt/sysroot/lib/aarch64-linux-gnu
```

### 不直接链接的库

以下库由 SDL2 在运行时动态加载：

| 库 | 说明 |
|----|------|
| libGLESv2.so | Mali GPU OpenGL ES 2.0 |
| libEGL.so | Mali GPU EGL |
| libdrm.so | Direct Rendering Manager |

**注意**: 不直接链接 libGLESv2.so 避免了 C++ ABI 不兼容问题。SDL2 在运行时通过 `dlopen` 加载 GL 函数。

## 补丁内容

`flycast2022-aarch64-chinese-savestate-720x720.patch` 包含：

1. **CMakeLists.txt** - 去掉直接链接 libGLESv2，去掉 cmake_policy CMP0026
2. **core/rend/gles/gldraw.cpp** - 720x720 等比缩放居中显示，不裁剪画面
3. **core/rend/gui.cpp** - 中文界面支持
4. **core/serialize.cpp/h** - 存档状态向前兼容
5. **core/hw/aica/sgc_if.cpp** - 音频修复
6. **core/hw/gdrom/gdromv3.cpp** - GD-ROM 修复
7. **core/hw/maple/maple_cfg.cpp** - Maple 总线修复
8. **core/hw/modem/modem.cpp** - 调制解调器修复
9. **core/hw/naomi/naomi.cpp** - Naomi 修复
10. **core/hw/pvr/pvr.cpp** - PVR 修复
11. **core/hw/pvr/spg.cpp** - SPG 修复
12. **core/hw/sh4/sh4_cache.h** - SH4 缓存修复

## 屏幕适配

### 720x720 屏幕

- 游戏画面 4:3 (640x480)
- 等比缩放：`scale = 720/640 = 1.125`
- 缩放后尺寸：720 x 540
- 上下黑边：`(720-540)/2 = 90` 像素
- **不裁剪，完整显示**

### 1280x720 屏幕

- 游戏画面 4:3 (640x480)
- 等比缩放：`scale = 720/480 = 1.5`
- 缩放后尺寸：960 x 720
- 左右黑边：`(1280-960)/2 = 160` 像素
- **不裁剪，完整显示**

### 640x480 屏幕

- 游戏画面 4:3 (640x480)
- 完美填满，无黑边

## 存档路径

| 类型 | 路径 |
|------|------|
| 配置目录 | `~/.config/flycast/` |
| 数据目录 | `~/.local/share/flycast/` |
| 快速存档 | `~/.local/share/flycast/<游戏ID>.state<N>` |
| 存档数据 | `~/.local/share/flycast/<游戏ID>.nvm` (VMU) |

### 快速存档快捷键

- `Shift+F1`~`F9` - 保存到槽位 1-9
- `F1`~`F9` - 从槽位 1-9 加载

## 目录结构

```
flycast2022/
├── aarch64-toolchain.cmake          # aarch64 工具链文件
├── arm32-toolchain.cmake            # arm32 工具链文件 (备用)
├── CMakeLists.txt                   # 主构建文件 (已修改)
├── build-aarch64/                   # aarch64 构建目录
│   └── flycast                      # 编译产物
├── build-arm32/                     # arm32 构建目录 (备用)
├── core/                            # 源代码
│   ├── rend/
│   │   ├── gles/gldraw.cpp          # 720x720 适配
│   │   └── gui.cpp                  # 中文支持
│   ├── serialize.cpp                # 存档序列化
│   └── hw/                          # 硬件模拟
├── flycast2022-aarch64-chinese-savestate-720x720.patch  # 补丁
└── BUILD_FLYCAST2022.md             # 本文档
```

## 常见问题

### Q: 编译时找不到 crt1.o

A: 确保 `-B/opt/sysroot/usr/lib/aarch64-linux-gnu` 在链接器标志中。

### Q: 编译时找不到 bits/libc-header-start.h

A: 创建 multiarch 符号链接：
```bash
sudo ln -sf /opt/sysroot/usr/include/aarch64-linux-gnu/bits /opt/sysroot/usr/include/bits
```

### Q: 编译时找不到 SDL2

A: 创建 SDL2 CMake 配置文件并指定 `-DSDL2_DIR`。

### Q: cmake_policy CMP0026 错误

A: 从 CMakeLists.txt 中移除 `cmake_policy(SET CMP0026 OLD)` 和相关的 `get_target_property`。

### Q: 运行时崩溃 Ill-formed 'bl' instruction

A: 这是 ARM32 版本的 VIXL bug，使用 aarch64 版本可解决。

### Q: 运行时找不到 libGLESv2.so

A: 确保目标设备有 Mali GPU 驱动，库路径在 `/usr/local/lib/aarch64-linux-gnu/` 或 `/usr/lib/aarch64-linux-gnu/`。

### Q: 720x720 屏幕画面被裁剪

A: 应用补丁后会等比缩放居中显示，上下加黑边，不裁剪。

## 参考资料

- [Flycast GitHub](https://github.com/flyinghead/flycast)
- [ARM 工具链下载](https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-a)
- [CMake 交叉编译文档](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
