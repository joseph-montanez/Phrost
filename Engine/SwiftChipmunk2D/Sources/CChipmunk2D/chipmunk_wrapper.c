#include "chipmunk_wrapper.h"

// Cast void* space to cpSpace* and call the original cpSpaceAddPostStepCallback function.
cpBool cpSpaceAddSwiftPostStepCallback(void *space, SwiftCPPostStepFunc func, void *key, void *data) {
    return cpSpaceAddPostStepCallback((cpSpace *)space, func, key, data);
}