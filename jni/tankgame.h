#ifndef _TANKGAME_H_
#define _TANKGAME_H_

#include <jni.h>
#include "jni-base.h"

jlong initCamera(JNIEnv *env, jobject thiz);
void lookAt(JNIEnv *env, jobject thiz, jlong address, jfloat ex, jfloat ey, jfloat ez,
		jfloat cx, jfloat cy, jfloat cz, jfloat ux, jfloat uy, jfloat uz);
void perspective(JNIEnv *env, jobject thiz, jlong address, jint l, jint r, jint t, jint b,
			jfloat fov, jfloat znear, jfloat zfar);
void project(JNIEnv *env, jobject thiz, jlong address, jfloatArray out,
		jfloat objX, jfloat objY, jfloat objZ);
void projectOrthor(JNIEnv *env, jobject thiz, jlong address, jfloatArray out,
		jfloat objX, jfloat objY, jfloat objZ);
void rotate(JNIEnv *env, jobject thiz, jlong address, jfloat yawR, jfloat pitchR, jfloat roll);
void moveAlongForward(JNIEnv *env, jobject thiz, jlong address, jfloat distance);
void jniReleaseCam(JNIEnv *env, jobject thiz, jlong address);

/*Camera's methods*/
static const JNINativeMethod CameraMethods[] = {
	{"initCamera", "()J", (void*)initCamera},
	{"lookAt", "(JFFFFFFFFF)V", (void*)lookAt},
	{"perspective", "(JIIIIFFF)V", (void*)perspective},
	{"project", "(J[FFFF)V", (void*)project},
	{"projectOrthor", "(J[FFFF)V", (void*)projectOrthor},
	{"rotate", "(JFFF)V", (void*)rotate},
	{"moveAlongForward", "(JF)V", (void*)moveAlongForward},
	{"jniRelease", "(J)V", (void*)jniReleaseCam}
};

#endif
