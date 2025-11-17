#ifndef CHIPMUNK_WRAPPER_H
#define CHIPMUNK_WRAPPER_H

#include "shims.h"

// Define the post-step callback function type.
typedef void (*SwiftCPPostStepFunc)(cpSpace *space, void *key, void *data);

// Wrapper for cpSpaceAddPostStepCallback to use Swift's function signature with void* space.
cpBool cpSpaceAddSwiftPostStepCallback(void *space, SwiftCPPostStepFunc func, void *key, void *data);

#endif // CHIPMUNK_WRAPPER_H