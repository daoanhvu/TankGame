#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <jni.h>
#include <android/log.h>
#include <StringUtil.h>
#include <nmath.h>
#include "camera.h"
#include <nmath_pool.h>
#include "function.h"

#define TOKEN_SIZE 100

#define ERROR_JNI_ERROR -1000

#define LOG_TAG "NativeCamera"
#define LOG_LEVEL 10
#define LOGI(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
#define LOGE(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

using namespace nmath;

extern const int RETURNVAL_CLASS;
extern const int FUNCTION_CLASS;
extern const int IMAGEDATA_CLASS;
extern const int TOKEN_CLASS ;
extern const int ARRAYLIST_CLASS;
extern const int CAMERA_CLASS;
extern jclass CLASSES[7];

extern const int RETURNVAL_VALUE_FIELD_IDX;
extern const int RETURNVAL_TEXT_FIELD_IDX;
extern const int RETURNVAL_ISNULL_FIELD_IDX;
extern const int TOKEN_COLUMN_FIELD_IDX;
extern const int TOKEN_PRIORITY_FIELD_IDX;
extern const int TOKEN_TYPE_FIELD_IDX;
extern jfieldID FIELDS[6];

extern const int ARRAYLIST_INIT;
extern const int ARRAYLIST_ADD;
extern const int TOKEN_GETTEXTLENGTH;
extern const int TOKEN_CHARAT;
extern const int IMAGEDATA_INIT;
extern jmethodID METHODS[5];

/**********************************************************************************/
typedef struct tagNMathData {
	NFunction f;
	NLabLexer lexer;
	NLabParser parser;
	Token tokens[TOKEN_SIZE];
}NMathData;

/*****************************************************************************************************************/

jlong initNativeObject(JNIEnv *env, jobject thiz) {
	NMathData *data = new NMathData;

	//data->f = new NFunction();
	//data->lexer = new NLabLexer();
	//data->parser = new NLabParser();

	return ((jlong)data);
}

jint jniCalc(JNIEnv *env, jobject thiz, jlong address, jstring function_text, jobject ret) {
	NMathData *data = (NMathData*)address;
	const char* text = env->GetStringUTFChars(function_text, NULL);
	int textLen = env->GetStringUTFLength( function_text);
	int tokenNum, start = 0;
	jstring valueText;
	char outString[256];
	jint errorCode;
	DParam rp;
	NMAST *t;

	tokenNum = (data->lexer).lexicalAnalysis(text, textLen, 0, data->tokens, 100/*capacity of mTokens*/, 0);
	errorCode = data->lexer.getErrorCode();
	if( errorCode == NMATH_NO_ERROR ) {
		t = data->parser.parseExpression(data->tokens, tokenNum, &start);
		errorCode = data->parser.getErrorCode();
		LOGI(2, "After parsing errorCode = : %d", errorCode);
		if( errorCode == NMATH_NO_ERROR) {
			rp.error = 0;
			rp.t = t;
			nmath::reduce_t((void*)&rp);
			errorCode = rp.error;
			LOGI(2, "After reducing errorCode = : %d", errorCode);
			if( errorCode == NMATH_NO_ERROR ) {
				start = 0;
				nmath::toString(rp.t, outString, &start, 256);
				outString[start] = 0;
				LOGI(2, "Calculating result: %s", outString);
				valueText = env->NewStringUTF(outString);
				env->SetDoubleField( ret, FIELDS[RETURNVAL_VALUE_FIELD_IDX], rp.t->value);
				env->SetBooleanField( ret, FIELDS[RETURNVAL_ISNULL_FIELD_IDX], JNI_FALSE);
				env->SetObjectField( ret, FIELDS[RETURNVAL_TEXT_FIELD_IDX], valueText);
			}
		}

		nmath::putIntoPool(rp.t);
	}

	return errorCode;
}

/**
	Return: error code
*/
int jniJLexerCalc(JNIEnv *env, jobject thiz, jlong nativeAddress, jobjectArray jtokenArr, jobject ret) {
	NMathData *data;
	jobject jtoken, jText;
	char outString[256];
	jstring valueText;
	jint i, j, l=0;
	jsize tokenNum = env->GetArrayLength(jtokenArr);

	data = (NMathData*)nativeAddress;
	data->f.release();

	for(i=0; i<tokenNum; i++) {
		jtoken = env->GetObjectArrayElement(jtokenArr, i);
		data->tokens[i].type = env->GetIntField(jtoken, FIELDS[TOKEN_TYPE_FIELD_IDX]);
		data->tokens[i].column = env->GetIntField(jtoken, FIELDS[TOKEN_COLUMN_FIELD_IDX]);
		data->tokens[i].priority = env->GetIntField(jtoken, FIELDS[TOKEN_PRIORITY_FIELD_IDX]);
		data->tokens[i].textLength = (unsigned char)env->CallIntMethod(jtoken, METHODS[TOKEN_GETTEXTLENGTH]);
		for(j=0; j<data->tokens[i].textLength; j++) {
			data->tokens[i].text[j] = (char)env->CallCharMethod(jtoken, METHODS[TOKEN_CHARAT], j);
		}
		data->tokens[i].text[j] = 0;

	}

	// LOGI(1, "Before parsing expression. Number of token: %d", tokenNum);
	i=0;
	if( data->f.parse(data->tokens, tokenNum, &(data->parser)) == NMATH_NO_ERROR ) {
		// LOGI(2, "After REDUCING, ERRORCODE: %d", getErrorCode());
		if(data->f.reduce() == NMATH_NO_ERROR) {
			l = data->f.toString(outString, 256);
			//LOGI(2, "Calculating result: %s", outString);
			valueText = env->NewStringUTF(outString);
			env->SetDoubleField( ret, FIELDS[RETURNVAL_VALUE_FIELD_IDX], data->f.getPrefix(0)->value);
			env->SetBooleanField( ret, FIELDS[RETURNVAL_ISNULL_FIELD_IDX], JNI_FALSE);
			env->SetObjectField( ret, FIELDS[RETURNVAL_TEXT_FIELD_IDX], valueText);
		}
	}
	
	return data->f.getErrorCode();
}

jobject jniJLexerGetSpace(JNIEnv *env, jobject thiz, jlong nativeAddress,
		jobjectArray jtokenArr, jfloatArray boundaries, jfloat epsilon, jboolean isNormal) {
	NMathData *data;
	DParamF dp;
	jobject jtoken, img;
	jint i, j, vertexCount;
	jsize tokenNum = env->GetArrayLength(jtokenArr);
	jfloat *bdarr = env->GetFloatArrayElements( boundaries, NULL);
	ListFData *spaces = NULL;
	jobject result = NULL;
	jfloatArray *farr;
	jintArray *rowInfo;
	jfloat floatBuff[512];
	float temp;
	//bool useNormal = (isNormal==JNI_TRUE)?true:false;

	data = (NMathData*)nativeAddress;
	data->f.release();

	//LOGI(2, "[Native] Number of token: %d", tokenNum);
	for(i=0; i<tokenNum; i++) {
		jtoken = env->GetObjectArrayElement(jtokenArr, i);
		data->tokens[i].type = env->GetIntField(jtoken, FIELDS[TOKEN_TYPE_FIELD_IDX]);
		data->tokens[i].column = env->GetIntField(jtoken, FIELDS[TOKEN_COLUMN_FIELD_IDX]);
		data->tokens[i].priority = env->GetIntField(jtoken, FIELDS[TOKEN_PRIORITY_FIELD_IDX]);
		data->tokens[i].textLength = (unsigned char)env->CallIntMethod(jtoken, METHODS[TOKEN_GETTEXTLENGTH]);
		for(j=0; j<data->tokens[i].textLength; j++) {
			data->tokens[i].text[j] = (char)env->CallCharMethod(jtoken, METHODS[TOKEN_CHARAT], j);
		}
		data->tokens[i].text[j] = 0;

		LOGI(2, "Type=%d, column=%d, priority=%d, text=%s", data->tokens[i].type,
				data->tokens[i].column, data->tokens[i].priority,
				data->tokens[i].text);
	}

	//LOGI(2, "AFTER parseExpression: ErrorCode=%d, ErrorColumn=%d", getErrorCode(), getErrorColumn());
	if( data->f.parse(data->tokens, tokenNum, &(data->parser)) == NMATH_NO_ERROR ) {
		//LOGI(2, "BEFORE getSpaces number of variable: %d", f->valLen);
		spaces = data->f.getSpace(bdarr, epsilon, isNormal);
		result = env->NewObject( CLASSES[ARRAYLIST_CLASS], METHODS[ARRAYLIST_INIT]);
		// LOGI(2, "AFTER FindClass ");
		if( (result != NULL) && (data->f.getErrorCode() == NMATH_NO_ERROR) ) {
			farr = (jfloatArray*)malloc(sizeof(jfloatArray) * spaces->size);
			rowInfo = (jintArray*)malloc(sizeof(jintArray) * spaces->size);
			for(i=0; i<spaces->size; i++) {
				farr[i] = env->NewFloatArray( spaces->list[i]->dataSize);
				rowInfo[i] = env->NewIntArray( spaces->list[i]->rowCount);
				//LOGI(2, "Space %d: size=%d", i, spaces->list[i]->dataSize);
				for(j=0; j<spaces->list[i]->dataSize; j++) {
					temp = spaces->list[i]->data[j];
					env->SetFloatArrayRegion( farr[i], j, 1, &temp );
				}

				env->SetIntArrayRegion( rowInfo[i], 0, spaces->list[i]->rowCount, spaces->list[i]->rowInfo);
				vertexCount = spaces->list[i]->dataSize/spaces->list[i]->dimension;
				img = env->NewObject( CLASSES[IMAGEDATA_CLASS], METHODS[IMAGEDATA_INIT], spaces->list[i]->dimension, farr[i], -1, vertexCount, rowInfo[i]);
				env->CallBooleanMethod( result, METHODS[ARRAYLIST_ADD], img);
			}
			free(farr);
			free(rowInfo);
		}
	}
	env->ReleaseFloatArrayElements( boundaries, bdarr, 0);
	return result;
}


/**
 * @Return
 * 		native address of derivative
 */
jint jniGetDerivative(JNIEnv *env, jobject thiz) {
	return 0;
}

jlong jniGetError(JNIEnv *env, jobject thiz, jlong address) {
	NMathData *data = (NMathData*)address;
	jlong code = data->f.getErrorCode();
	jlong col = data->f.getErrorColumn();
	jlong result = (code << 32) | col;
	return result;
}

void jniRelease(JNIEnv *env, jobject thiz) {
	jfieldID nativeAddrField = env->GetFieldID( CLASSES[FUNCTION_CLASS], "nativeAddress", "J");
	jlong nativeAddress = env->GetLongField( thiz, nativeAddrField);
	NMathData *data;
	if(nativeAddress > 0){
		data = (NMathData*)nativeAddress;
		data->f.release();
		delete data;
	}
	env->SetLongField( thiz, nativeAddrField, 0);
}

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
