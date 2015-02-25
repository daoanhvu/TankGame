APP_CFLAGS += -Wno-error=format-security
APP_STL         := stlport_static #stlport_shared
#APP_STL := gnustl_static
APP_ABI := armeabi armeabi-v7a x86 mips
NDK_TOOLCHAIN_VERSION:=4.9
