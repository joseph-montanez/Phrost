#ifndef PTHREAD_SHIM_H
#define PTHREAD_SHIM_H

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <process.h>

// --- Types ---
typedef HANDLE pthread_t;
typedef CRITICAL_SECTION pthread_mutex_t;
typedef CONDITION_VARIABLE pthread_cond_t;

// --- Mutex ---
static inline int pthread_mutex_init(pthread_mutex_t* m, void* attr) {
    InitializeCriticalSection(m);
    return 0;
}
static inline int pthread_mutex_lock(pthread_mutex_t* m) {
    EnterCriticalSection(m);
    return 0;
}
static inline int pthread_mutex_unlock(pthread_mutex_t* m) {
    LeaveCriticalSection(m);
    return 0;
}
static inline int pthread_mutex_destroy(pthread_mutex_t* m) {
    DeleteCriticalSection(m);
    return 0;
}

// --- Condition Variable ---
static inline int pthread_cond_init(pthread_cond_t* c, void* attr) {
    InitializeConditionVariable(c);
    return 0;
}
static inline int pthread_cond_signal(pthread_cond_t* c) {
    WakeConditionVariable(c);
    return 0;
}
static inline int pthread_cond_wait(pthread_cond_t* c, pthread_mutex_t* m) {
    // SleepConditionVariableCS releases the CS (mutex) and waits
    if (!SleepConditionVariableCS(c, m, INFINITE)) return 1;
    return 0;
}
static inline int pthread_cond_destroy(pthread_cond_t* c) {
    // No cleanup needed for CONDITION_VARIABLE on Windows
    return 0;
}

// --- Threads ---
static inline int pthread_create(pthread_t* thread, void* attr, void* (*start_routine)(void*), void* arg) {
    *thread = (HANDLE)_beginthreadex(NULL, 0, (unsigned(__stdcall*)(void*))start_routine, arg, 0, NULL);
    return (*thread == 0) ? 1 : 0;
}
static inline int pthread_detach(pthread_t thread) {
    CloseHandle(thread);
    return 0;
}
static inline int pthread_join(pthread_t thread, void** retval) {
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
    return 0;
}
#else
// Non-Windows: Just include standard pthread
#include <pthread.h>
#endif

#endif // PTHREAD_SHIM_H
