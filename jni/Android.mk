LOCAL_PATH		:= $(call my-dir)

include $(CLEAR_VARS)

FEATURE_NEON:=

#if armeabi-v7a
ifeq ($(TARGET_ARCH_ABI), armeabi-v7a)
	# add neon optimization code (only armeabi-v7a)
	FEATURE_NEON:=yes
else

endif

#NMATH_SRC_DIR:=$(LOCAL_PATH)/../../../nmath2/linux
#NMATH_SRC_DIR:=$(LOCAL_PATH)/../../../libnmath/linux
#NMATH_SRC_FILES:=$(NMATH_SRC_DIR)/common.c \
#				$(NMATH_SRC_DIR)/nlablexer.c \
#				$(NMATH_SRC_DIR)/nlabparser.c \
#				$(NMATH_SRC_DIR)/criteria.c \
#				$(NMATH_SRC_DIR)/nmath.c

GM_DIR:=$(LOCAL_PATH)/../../../libnmath/gm
#GM_SRC_FILES:=$(GM_DIR)/fmat4.cpp
#NMATH_SRC_DIR:=$(LOCAL_PATH)/../../../nmath2/cpp
NMATH_SRC_DIR:=$(LOCAL_PATH)/../../../libnmath/cpp2
NMATH_SRC_FILES:=$(NMATH_SRC_DIR)/common.cpp \
				$(NMATH_SRC_DIR)/nmath_pool.cpp \
				$(NMATH_SRC_DIR)/nlablexer.cpp \
				$(NMATH_SRC_DIR)/nlabparser.cpp \
				$(NMATH_SRC_DIR)/criteria.cpp \
				$(NMATH_SRC_DIR)/nfunction.cpp \
				$(NMATH_SRC_DIR)/SimpleCriteria.cpp \
				$(NMATH_SRC_DIR)/compositecriteria.cpp \
				$(NMATH_SRC_DIR)/StringUtil.cpp \
				$(NMATH_SRC_DIR)/StackUtil.cpp \
				
IME_JNI_SRC_FILES := \
	kb/ProximityInfo.cpp \
	kb/utils/char_utils.cpp \
	kb/utils/autocorrection_threshold_utils.cpp \
	kb/suggest/core/layout/proximity_info_params.cpp \
    kb/suggest/core/layout/proximity_info.cpp

# Define vars for library that will be build statically.
#include $(CLEAR_VARS)
#LOCAL_MODULE := nmath2
#LOCAL_C_INCLUDES := $(NMATH_SRC_DIR)
#LOCAL_SRC_FILES :=  $(NMATH_SRC_FILES)
# Optional compiler flags.
#LOCAL_LDLIBS   = -lz -lm
#LOCAL_CFLAGS   = -Wall -pedantic -std=c99 -g
#include $(BUILD_STATIC_LIBRARY)

#include $(CLEAR_VARS)
#LOCAL_MODULE := nmath2
#LOCAL_SRC_FILES :=  nmath2.a
#include $(PREBUILT_STATIC_LIBRARY) 

include $(CLEAR_VAR)
ifdef FEATURE_NEON
	#Be careful with this flag
	LOCAL_ALLOW_UNDEFINED_SYMBOLS := false
	LOCAL_MODULE := nmath-neon
	LOCAL_MODULE_FILENAME := libnmath-neon
#	LOCAL_CFLAGS    := -Werror -DDEBUG -D_TARGET_HOST_ANDROID #-Wall -Wextra
	LOCAL_CFLAGS    := -Werror -D_TARGET_HOST_ANDROID #-Wall -Wextra -Wno-unused-parameter -Wno-unused-function
	LOCAL_SRC_FILES := $(NMATH_SRC_FILES) jni-base.cpp function-jni.cpp camera.cpp function.cpp $(IME_JNI_SRC_FILES)
#	LOCAL_SRC_FILES := jni-base.cpp function-jni.cpp function.cpp $(IME_JNI_SRC_FILES)
	LOCAL_C_INCLUDES := $(GM_DIR) $(LOCAL_PATH) $(NMATH_SRC_DIR)
#	LOCAL_STATIC_LIBRARIES := nmath2
	LOCAL_LDLIBS    := -lm -llog
	include $(BUILD_SHARED_LIBRARY)
endif

#Be careful with this flag
LOCAL_ALLOW_UNDEFINED_SYMBOLS := false
LOCAL_MODULE	:= nmath
LOCAL_MODULE_FILENAME := libnmath
#LOCAL_CFLAGS    := -Werror -DDEBUG -D_TARGET_HOST_ANDROID #-Wall -Wextra
LOCAL_CFLAGS    := -Werror -D_TARGET_HOST_ANDROID #-Wall -Wextra -Wno-unused-parameter -Wno-unused-function
LOCAL_SRC_FILES :=$(NMATH_SRC_FILES) jni-base.cpp function-jni.cpp camera.cpp function.cpp $(IME_JNI_SRC_FILES)
#LOCAL_SRC_FILES :=jni-base.cpp function-jni.cpp function.cpp $(IME_JNI_SRC_FILES) 
LOCAL_C_INCLUDES := $(GM_DIR) $(LOCAL_PATH) $(NMATH_SRC_DIR)
#LOCAL_LDLIBS    := -lm -lpthread -llog -lGLESv2
#LOCAL_STATIC_LIBRARIES := nmath2
LOCAL_LDLIBS    := -lm -llog
include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VAR)
LOCAL_ALLOW_UNDEFINED_SYMBOLS := false
LOCAL_MODULE := nativetester
LOCAL_MODULE_FILENAME := libnativetester
LOCAL_SRC_FILES := nativetest-jni.cpp nativetest.cpp
LOCAL_STATIC_LIBRARIES := cpufeatures
LOCAL_LDLIBS  := -llog
include $(BUILD_SHARED_LIBRARY)

$(call import-module, cpufeatures)