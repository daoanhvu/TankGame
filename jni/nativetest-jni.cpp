#include <jni.h>
#include <android/log.h>
#include <cpu-features.h>
#include <stdlib.h>
#include "nativetest.h"

#define LOG_TAG "NativeTester"
#define LOG_LEVEL 10
#define LOGI(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
#define LOGE(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

static int register_native_method(JNIEnv *env, const char *clsName, JNINativeMethod *methods, int numOfMethod) {
	jclass cls;
	cls = env->FindClass(clsName);

	if(cls == NULL){
		LOGE(1, "Unable to find class '%s' \n", clsName);
		return JNI_FALSE;
	}

	if( env->RegisterNatives(cls, methods, numOfMethod) < 0 ) {
		LOGE(1, "Register methods failed \n");
		return JNI_FALSE;
	}

	return JNI_TRUE;
}

/**
 * JNI Callback functions
 * */
jint JNICALL JNI_OnLoad(JavaVM *vm, void* reserved) {
	JNIEnv *env;
	jint result = -1;
	int isRegMethoOk;

	if( vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK ) {
		LOGE(1, "Register methods failed \n");
		return result;
	}

	isRegMethoOk = register_native_method(env, nativetesterClassPath, 
								nativetester_methods, 1);
	if(isRegMethoOk < 0){
		return -1;
	}

	result = JNI_VERSION_1_6;
	return result;
}

/*
void JNI_OnUnload(JavaVM *vm, void *reserved){
}
*/