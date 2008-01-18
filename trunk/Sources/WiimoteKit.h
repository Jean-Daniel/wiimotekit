/*
 *  WiimoteKit.h
 *  WiimoteKit
 *
 *  Created by Jean-Daniel Dupas on 13/01/08.
 *  Copyright 2008 Shadow Lab.. All rights reserved.
 *
 */

#if !defined(__WIIMOTEKIT_H)
#define __WIIMOTEKIT_H 1

#include <mach/mach_error.h>

#define WKLog(str, args...) NSLog(str, ##args)
#define WKPrintIOReturn(result, str) if (kIOReturnSuccess != result) { fprintf(stderr, "%s: %s\n", str, mach_error_string(result)); }


#endif /* __WIIMOTEKIT_H */
