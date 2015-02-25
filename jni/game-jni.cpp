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

extern int RETURNVAL_CLASS;
extern int FUNCTION_CLASS;
extern int IMAGEDATA_CLASS;
extern int TOKEN_CLASS;
extern int PROXIMITYINFO_CLASS;
extern int ARRAYLIST_CLASS;
extern int CAMERA_CLASS;
extern jclass CLASSES[7];

extern int ARRAYLIST_INIT;
extern int ARRAYLIST_ADD;
extern int TOKEN_GETTEXTLENGTH;
extern int TOKEN_CHARAT;
extern int IMAGEDATA_INIT;
extern jmethodID METHODS[5];

extern int RETURNVAL_VALUE_FIELD_IDX;
extern int RETURNVAL_TEXT_FIELD_IDX;
extern int RETURNVAL_ISNULL_FIELD_IDX;
extern int TOKEN_COLUMN_FIELD_IDX;
extern int TOKEN_PRIORITY_FIELD_IDX;
extern int TOKEN_TYPE_FIELD_IDX;
extern jfieldID FIELDS[6];

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
	jclass clsReturnVal, clsFunction, clsImageData;
	jclass clsToken, clsProximityInfo, clsArrayList, clsCamera;
	int isRegMethod1;
	int isRegMethod2, isRegClsCamera;

	char JReturnValClassPath[] = "simplemath/math/ReturnVal";
	char JFunctionClassPath[] = "simplemath/math/Function";
	char JImageDataClassPath[] = "simplemath/math/ImageData";
	char JTokenClassPath[] = "nautilus/functionplotter/formula/Token";
	char JProximityInfoClassPath[] = "nautilus/nmath/keyboard/ProximityInfo";
	char JCameraClassPath[] = "nautilus/util/Camera";

	if( vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK ) {
		LOGE(1, "Register methods failed \n");
		return result;
	}

	/* Registry classes */
	clsReturnVal = env->FindClass(JReturnValClassPath);
	clsFunction = env->FindClass(JFunctionClassPath);
	clsImageData = env->FindClass(JImageDataClassPath);
	clsToken = env->FindClass(JTokenClassPath);	
	clsProximityInfo = env->FindClass(JProximityInfoClassPath);	
	clsArrayList = env->FindClass("java/util/ArrayList");
	clsCamera = env->FindClass(JCameraClassPath);

	if(clsReturnVal == NULL) {
		LOGE(1, "Cannot find class %s \n", JReturnValClassPath);
	}

	if(clsFunction == NULL) {
		LOGE(1, "Cannot find class %s \n", JFunctionClassPath);
	}

	if(clsImageData == NULL) {
		LOGE(1, "Cannot find class %s \n", JImageDataClassPath);
	}

	if(clsToken == NULL) {
		LOGE(1, "Cannot find class %s \n", JTokenClassPath);
	}

	if(clsProximityInfo == NULL) {
		LOGE(1, "Cannot find class %s \n", JProximityInfoClassPath);
	}

	if(clsArrayList == NULL) {
		LOGE(1, "Cannot find class java/util/ArrayList \n");
	}

	if(clsCamera == NULL) {
		LOGE(1, "Cannot find class Lnautilus/util/Camera \n");
	}

	METHODS[TOKEN_GETTEXTLENGTH] = env->GetMethodID(clsToken, "getTextLength", "()I");
	METHODS[TOKEN_CHARAT] = env->GetMethodID(clsToken, "charAt", "(I)C");

	METHODS[IMAGEDATA_INIT] = env->GetMethodID(clsImageData, "<init>", "(I[FII[I)V");

	METHODS[ARRAYLIST_INIT] = env->GetMethodID( clsArrayList, "<init>", "()V");
	METHODS[ARRAYLIST_ADD] = env->GetMethodID( clsArrayList, "add", "(Ljava/lang/Object;)Z");

	/* Get fields those be used requently */
	FIELDS[RETURNVAL_VALUE_FIELD_IDX] = env->GetFieldID( clsReturnVal, "value", "D");
	FIELDS[RETURNVAL_TEXT_FIELD_IDX]  = env->GetFieldID( clsReturnVal, "valueText", "Ljava/lang/String;");
	FIELDS[RETURNVAL_ISNULL_FIELD_IDX] = env->GetFieldID( clsReturnVal, "isNull", "Z");

	FIELDS[TOKEN_COLUMN_FIELD_IDX] = env->GetFieldID(clsToken, "column", "I");
	FIELDS[TOKEN_PRIORITY_FIELD_IDX] = env->GetFieldID(clsToken, "priority", "I");
	FIELDS[TOKEN_TYPE_FIELD_IDX] = env->GetFieldID(clsToken, "type", "I");

	CLASSES[RETURNVAL_CLASS] 	= (jclass)env->NewGlobalRef(clsReturnVal);
	CLASSES[FUNCTION_CLASS] 	= (jclass)env->NewGlobalRef(clsFunction);
	CLASSES[IMAGEDATA_CLASS] 	= (jclass)env->NewGlobalRef(clsImageData);
	CLASSES[TOKEN_CLASS] 		= (jclass)env->NewGlobalRef(clsToken);
	CLASSES[PROXIMITYINFO_CLASS] 	= (jclass)env->NewGlobalRef(clsProximityInfo);
	CLASSES[ARRAYLIST_CLASS] 	= (jclass)env->NewGlobalRef(clsArrayList);
	CLASSES[CAMERA_CLASS] 	= (jclass)env->NewGlobalRef(clsCamera);
	
	isRegMethod1 = register_native_method(env, clsFunction, JFunctionClassPath, functionMethods, 7);
	isRegMethod2 = register_native_method(env, clsProximityInfo, JProximityInfoClassPath, proximityMethods, 2);
	isRegClsCamera = register_native_method(env, clsCamera, JCameraClassPath, CameraMethods, 8);

	env->DeleteLocalRef(clsReturnVal);
	env->DeleteLocalRef(clsFunction);
	env->DeleteLocalRef(clsImageData);
	env->DeleteLocalRef(clsToken);
	env->DeleteLocalRef(clsProximityInfo);
	env->DeleteLocalRef(clsArrayList);
	env->DeleteLocalRef(clsCamera);

	if( (isRegMethod1 < 0) || (isRegMethod2 < 0) ) {
		return -1;
	}

	nmath::initNMASTPool();
	result = JNI_VERSION_1_6;
	return result;
}


void JNI_OnUnload(JavaVM *vm, void *reserved) {
	JNIEnv *env;
	nmath::releaseNMASTPool();
	if( vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK ) {
		LOGE(1, "[JNI_OnUnload] Register methods failed \n");
	}

	env->DeleteGlobalRef(CLASSES[RETURNVAL_CLASS]);
	env->DeleteGlobalRef(CLASSES[FUNCTION_CLASS]);
	env->DeleteGlobalRef(CLASSES[IMAGEDATA_CLASS]);
	env->DeleteGlobalRef(CLASSES[TOKEN_CLASS]);
	env->DeleteGlobalRef(CLASSES[PROXIMITYINFO_CLASS]);
	env->DeleteGlobalRef(CLASSES[ARRAYLIST_CLASS]);
	env->DeleteGlobalRef(CLASSES[CAMERA_CLASS]);
}

