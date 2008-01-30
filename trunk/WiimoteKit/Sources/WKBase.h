/*
 *  WKBase.h
 *  WiimoteKit
 *
 *  Created by Jean-Daniel Dupas on 16/01/08.
 *  Copyright 2008 Shadow Lab. All rights reserved.
 */

#include <mach/mach_error.h>

#define WKLog(str, args...) NSLog(str, ##args)
#define WKPrintIOReturn(result, str) if (kIOReturnSuccess != result) { fprintf(stderr, "%s: %s\n", str, mach_error_string(result)); }
