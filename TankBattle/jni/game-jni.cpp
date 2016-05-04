#include <stdio.h>
#include <stdlib.h>
#include <jni.h>
#include <android/log.h>
#include <assert.h>
#include <nmath_pool.h>
#include "function.h"
#include "jni-base.h"
#include "kb/ProximityInfo.h"

#ifndef NELEM
#define NELEM(x) ((int)sizeof(x)/sizeof((x)[0]))
#endif

#define LOG_TAG "NATIVE_NMATH"
#define LOG_LEVEL 10
#define LOGI(level, ...) if (level<=LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
#define LOGE(level, ...) if (level<=LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

extern int ARRAYLIST_CLASS;
extern int CAMERA_CLASS;
extern jclass CLASSES[2];

extern int ARRAYLIST_INIT;
extern int ARRAYLIST_ADD;
extern jmethodID METHODS[2];

/*
extern int RETURNVAL_VALUE_FIELD_IDX;
extern int RETURNVAL_TEXT_FIELD_IDX;
extern int RETURNVAL_ISNULL_FIELD_IDX;
extern int TOKEN_COLUMN_FIELD_IDX;
extern int TOKEN_PRIORITY_FIELD_IDX;
extern int TOKEN_TYPE_FIELD_IDX;
extern jfieldID FIELDS[6];
*/

static int register_native_method(JNIEnv *env, const jclass cls, const char* clsName, const JNINativeMethod *methods, int numOfMethod) {
	
	if(cls == NULL){
		LOGE(1, "Unable to find class '%s' \n", clsName);
		return JNI_FALSE;
	}

	if( env->RegisterNatives(cls, methods, numOfMethod) < 0 ) {
		LOGE(1, "Register methods for class %s failed \n", clsName);
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
	jclass clsArrayList, clsCamera;
	int isRegMethod1;
	int isRegMethod2, isRegClsCamera;
	char JCameraClassPath[] = "com/nautilus/tankbattle/game/Camera3D";

	if( vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK ) {
		LOGE(1, "Register methods failed \n");
		return result;
	}

	/* Registry classes */
	clsArrayList = env->FindClass("java/util/ArrayList");
	clsCamera = env->FindClass(JCameraClassPath);

	if(clsArrayList == NULL) {
		LOGE(1, "Cannot find class java/util/ArrayList \n");
	}

	if(clsCamera == NULL) {
		LOGE(1, "Cannot find class Lcom/nautilus/tankbattle/game/Camera3D \n");
	}

	METHODS[ARRAYLIST_INIT] = env->GetMethodID( clsArrayList, "<init>", "()V");
	METHODS[ARRAYLIST_ADD] = env->GetMethodID( clsArrayList, "add", "(Ljava/lang/Object;)Z");

	/* Get fields those be used requently */
	CLASSES[CAMERA_CLASS] 	= (jclass)env->NewGlobalRef(clsCamera);
	isRegClsCamera = register_native_method(env, clsCamera, JCameraClassPath, CameraMethods, 8);


	env->DeleteLocalRef(clsArrayList);
	env->DeleteLocalRef(clsCamera);

	if( isRegClsCamera < 0 ) {
		return -1;
	}

	result = JNI_VERSION_1_6;
	return result;
}


void JNI_OnUnload(JavaVM *vm, void *reserved) {
	JNIEnv *env;
	if( vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK ) {
		LOGE(1, "[JNI_OnUnload] Register methods failed \n");
	}

	env->DeleteGlobalRef(CLASSES[ARRAYLIST_CLASS]);
	env->DeleteGlobalRef(CLASSES[CAMERA_CLASS]);
}

