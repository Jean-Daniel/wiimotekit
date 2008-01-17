/*
 *  WiiRemoteInterbal.h
 *  WiimoteKit
 *
 *  Created by Jean-Daniel Dupas on 16/01/08.
 *  Copyright 2008 Shadow Lab.. All rights reserved.
 *
 */

#import <WiimoteKit/WiiRemote.h>
#import <WiimoteKit/WiimoteKit.h>

enum {
	kWKMemorySpaceWiiRemote = 1,
	kWKMemorySpaceExtension,
	kWKMemorySpaceIRCamera,
	kWKMemorySpaceSpeaker,
} ;
typedef NSUInteger WKAddressSpace;

// Wiimote registers (relative to respective address range)
#define IR_REGISTER_STATUS              0x30
#define IR_REGISTER_SENSITIVITY_1       0x00
#define IR_REGISTER_SENSITIVITY_2       0x1a
#define IR_REGISTER_MODE                0x33

#define EXTENSION_REGISTER_STATUS       0x40
#define EXTENSION_REGISTER_TYPE         0xfe
#define EXTENSION_REGISTER_CALIBRATION  0x20

#define WII_DECRYPT(data) (((data ^ 0x17) + 0x17) & 0xFF)

enum {
	/* WiiRemote */
	kWKWiiRemoteCalibrationRequest = 1,
	/* Extension */
	kWKExtensionTypeRequest,
	kWKExtensionCalibrationRequest,
	/* Mii */
	kWKMiiDataRequest,
};
typedef NSUInteger WKReadRequest;

// Wiimote output commands
enum WKOutputReport {
	WKOutputReportNone        = 0x00,
	//WKOutputReport???     = 0x10,
	WKOutputReportLEDs        = 0x11, // 1 byte
	WKOutputReportMode        = 0x12, // 2 bytes
	WKOutputReportIRCamera    = 0x13, // 1 byte
	WKOutputReportStatus      = 0x15, // 1 byte
	WKOutputReportWriteMemory = 0x16, // 21 byte
	WKOutputReportReadMemory  = 0x17, // 6 byte
	WKOutputReportSpeaker     = 0x18, // 21 byte
	WKOutputReportMuteSpeaker = 0x19, // 1
	WKOutputReportIRCamera2   = 0x1a, // 1 byte
};

@interface WiiRemote (WiiRemoteInternal)

- (IOReturn)initializeExtension;

- (void)setExtension:(WKExtension *)anExtension;
- (void)setExtensionType:(WKExtensionType)extensionType;

- (IOReturn)sendCommand:(const uint8_t *)cmd length:(size_t)length context:(void *)ctxt;

- (void)didReceiveAck:(const uint8_t *)ack;
- (IOReturn)writeData:(const uint8_t *)data length:(size_t)length 
						atAddress:(user_addr_t)address space:(WKAddressSpace)space context:(void *)ctxt;

- (IOReturn)readDataAtAddress:(user_addr_t)address space:(WKAddressSpace)space length:(size_t)length request:(NSUInteger)request;

@end

static __inline__ 
NSUInteger __WKReadRequestCount(NSUInteger stack) {
	return stack & 0xf;
}

static __inline__ 
NSUInteger __WKReadRequestPush(NSUInteger stack, WKReadRequest request) {
	NSCParameterAssert(request <= 0x0f);
	NSUInteger count = __WKReadRequestCount(stack);
	if (count == (sizeof(NSUInteger) * 2 - 1))
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"read stack overflow" userInfo:nil];
	
	NSUInteger shift = (count + 1) * 4;
	WKLog(@"=> Push read request: %u", request);
	
	stack &= ~((0xf << shift) | 0xf);
	stack |= request << shift | (count + 1);
	return stack;
}

static __inline__ 
NSUInteger __WKReadRequestPop(NSUInteger stack, WKReadRequest *request) {
	NSCParameterAssert(request);
	NSUInteger count = __WKReadRequestCount(stack);
	if (0 == count)
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"read stack underflow" userInfo:nil];
	
	*request = (stack & 0xf0) >> 4;
	WKLog(@"<= Pop read request: %u", *request);
	
	stack &= ~0xf0;
	return (stack >> 4) | (count - 1);
}
