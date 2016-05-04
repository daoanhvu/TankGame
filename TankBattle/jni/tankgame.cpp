#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <jni.h>
#include <android/log.h>
#include "camera.h"
#include "tankgame.h"

#define TOKEN_SIZE 100

#define ERROR_JNI_ERROR -1000

#define LOG_TAG "NativeCamera"
#define LOG_LEVEL 10
#define LOGI(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
#define LOGE(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

using namespace nmath;

extern const int ARRAYLIST_CLASS;
extern const int CAMERA_CLASS;
extern jclass CLASSES[2];

/*
extern const int RETURNVAL_VALUE_FIELD_IDX;
extern const int RETURNVAL_TEXT_FIELD_IDX;
extern const int RETURNVAL_ISNULL_FIELD_IDX;
extern const int TOKEN_COLUMN_FIELD_IDX;
extern const int TOKEN_PRIORITY_FIELD_IDX;
extern const int TOKEN_TYPE_FIELD_IDX;
extern jfieldID FIELDS[6];
*/

extern const int ARRAYLIST_INIT;
extern const int ARRAYLIST_ADD;
extern jmethodID METHODS[2];

/*****************************************************************************************************************/

//Camera

jlong initCamera(JNIEnv *env, jobject thiz) {
	fp::Camera *c;
	c = new fp::Camera();
	return ((jlong)c);
}

void lookAt(JNIEnv *env, jobject thiz, jlong address, jfloat ex, jfloat ey, jfloat ez,
		jfloat cx, jfloat cy, jfloat cz, jfloat ux, jfloat uy, jfloat uz) {
	fp::Camera *c = (fp::Camera*)address;
	c->lookAt(ex, ey, ez, cx, cy, cz, ux, uy, uz);
}

void perspective(JNIEnv *env, jobject thiz, jlong address, jint l, jint r, jint t, jint b,
			jfloat fov, jfloat znear, jfloat zfar) {
	fp::Camera *c = (fp::Camera*)address;
	c->setViewport(l, t, r, b);
	c->setPerspective(fov, znear, zfar);
}

void project(JNIEnv *env, jobject thiz, jlong address, jfloatArray out,
		jfloat objX, jfloat objY, jfloat objZ) {
	static float tmp[3];
	fp::Camera *c = (fp::Camera*)address;
	c->project(tmp, objX, objY, objZ);
//#ifdef _DEBUG
//	LOGI(2, "After project %f %f %f", tmp[0], tmp[1], tmp[2]);
//#endif
	env->SetFloatArrayRegion(out, 0, 2, tmp);
}

void projectOrthor(JNIEnv *env, jobject thiz, jlong address, jfloatArray out,
		jfloat objX, jfloat objY, jfloat objZ) {
	static float tmp[3];
	fp::Camera *c = (fp::Camera*)address;
	c->projectOrthor(tmp, objX, objY, objZ);
	env->SetFloatArrayRegion(out, 0, 3, tmp);
}

void rotate(JNIEnv *env, jobject thiz, jlong address, jfloat yawR, jfloat pitchR, jfloat roll) {
	fp::Camera *c = (fp::Camera*)address;
	c->rotate(yawR, pitchR, roll);
}

void jniReleaseCam(JNIEnv *env, jobject thiz, jlong address) {
	jfieldID nativeAddrField = env->GetFieldID( CLASSES[CAMERA_CLASS], "nativeCamera", "J");
	fp::Camera *c;
	if(address > 0){
		c = (fp::Camera*)address;
		delete c;
	}
	env->SetLongField( thiz, nativeAddrField, 0);
}

void moveAlongForward(JNIEnv *env, jobject thiz, jlong address, jfloat distance) {
	fp::Camera *c = (fp::Camera*)address;
	c->moveAlongForward(distance);
}
