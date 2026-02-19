// ios_compat.h — iOS compatibility layer replacing Windows API calls
// Ported from MENTALITY V2 PC (D3D11/Win32) → Metal/iOS
#pragma once

#include <stdint.h>
#include <mach/mach_time.h>
#include <sys/time.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#endif

// Replace DWORD with uint32_t
#ifndef DWORD
typedef uint32_t DWORD;
#endif

#ifndef UINT
typedef unsigned int UINT;
#endif

#ifndef BOOL_DEFINED
#define BOOL_DEFINED
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef PVOID
typedef void* PVOID;
#endif

#ifndef ULONG
typedef unsigned long ULONG;
#endif


static inline DWORD GetTickCount_iOS() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (DWORD)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}
#define GetTickCount() GetTickCount_iOS()

static inline short GetAsyncKeyState_iOS(int vKey) {
    (void)vKey;
    return 0; // Always return not pressed
}
#define GetAsyncKeyState(x) GetAsyncKeyState_iOS(x)

// VK_ constants stubs
#ifndef VK_OEM_PLUS
#define VK_OEM_PLUS  0xBB
#define VK_OEM_MINUS 0xBD
#define VK_INSERT    0x2D
#endif

// min/max for compatibility
#ifndef min
#define min(a,b) ((a) < (b) ? (a) : (b))
#endif
#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif
