#ifndef _JNI_BASE_H_
#define _JNI_BASE_H_
#include <jni.h>

typedef struct {
    const char* name;
    const char* signature;
} JavaMethod;

typedef struct {
    char* name;
    char* signature;
} JavaField;

#endif
