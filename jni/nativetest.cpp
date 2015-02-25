#include <stdlib.h>
#include <jni.h>
#include <android/log.h>
#include <cpu-features.h>
#include "nativetest.h"

#define LOG_TAG "NativeTester"
#define LOG_LEVEL 10
#define LOGI(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
#define LOGE(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

jboolean jniIsNeon(JNIEnv *env, jobject thiz) {
	uint64_t features;
#ifdef FEATURE_NEON

	if (android_getCpuFamily() != ANDROID_CPU_FAMILY_ARM) {
		LOGI(5, "Not an ARM CPU\n");
		return JNI_FALSE;
	}

	features = android_getCpuFeatures();

	if ((features & ANDROID_CPU_ARM_FEATURE_ARMv7) == 0) {
		LOGI(5, "Not an ARMv7 CPU\n");
		return JNI_FALSE;
	}

	if ((features & ANDROID_CPU_ARM_FEATURE_NEON) == 0) {
		LOGI(5, "CPU doesn't support NEON\n");
		return JNI_FALSE;
	}

	return JNI_TRUE;
#else
	return JNI_FALSE;
#endif
}