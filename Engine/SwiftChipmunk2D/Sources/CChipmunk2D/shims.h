#if __APPLE__
    #error "Use Chipmunk2D.xcframework"
#elif defined(WIN32) || defined(_WIN32) || defined(__WIN32__) || defined(__NT__)
    #if __has_include("windows_generated.h")
        #include "windows_generated.h"
    #else
        #include "windows.h"
    #endif
#elif __linux__
    #include "linux.h" // Linux-specific Chipmunk2D headers or configuration
#else
   #error "Unsupported platform"
#endif