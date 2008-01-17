//
//  WiiRemoteInternal.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 16/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import "WiiRemoteInternal.h"

#import <WiimoteKit/WiimoteKit.h>
#import <WiimoteKit/WKExtension.h>
#import <WiimoteKit/WKConnection.h>

/* 
 address format: ffaaaaaa.
 ff: flags. 0x4 mean "access register" and is vital if you do not want to read or write anywhere in the wiimote eeprom.
 aaaaaa: virtual address.
 */
static __inline__
user_addr_t __WiiRemoteTranslateAddress(user_addr_t address, WKAddressSpace space) {
	switch (space) {
		case kWKMemorySpaceExtension:
			return address + 0x04a40000;
			break;
		case kWKMemorySpaceSpeaker:
			return address + 0x04a20000;
			break;
		case kWKMemorySpaceIRCamera:
			return address + 0x04b00000;
			break;
		case kWKMemorySpaceWiiRemote:
			return address;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"invalid address space" userInfo:nil];
	}
}

@implementation WiiRemote (WiiRemoteInternal)

- (IOReturn)sendCommand:(const uint8_t *)cmd length:(size_t)length context:(void *)ctxt {
	NSParameterAssert(length <= 22);
	uint8_t buffer[23];
	bzero(buffer, 23);
	
	buffer[0] = 0x52; /* magic number (HID spec) */
	memcpy(buffer + 1, cmd, length);
	if ([self isRumbleEnabled]) buffer[2] |= 1; // rumble bit must be set in all control report.
	
	WKLog(@"=> Send command %#x (cmd[1]: %#x,  cmd[2]: %#x) (%p)", cmd[0], length > 1 ? cmd[1] : 0, length > 2 ? cmd[2] : 0, ctxt);
	return [[self connection] sendData:buffer length:length + 1 context:ctxt];
}

- (IOReturn)writeData:(const uint8_t *)data length:(size_t)length atAddress:(user_addr_t)address space:(WKAddressSpace)space context:(void *)ctxt {
	NSParameterAssert(length <= 16);
	
	uint8_t buffer[22];
	bzero(buffer, 22);
	buffer[0] = WKOutputReportWriteMemory;
	
	user_addr_t vmaddr = __WiiRemoteTranslateAddress(address, space);
	
#if !defined(WII_ALLOW_UNSAFE_WRITE)
	if (space == kWKMemorySpaceWiiRemote && (address < 0x0fca || address > 0x15a9))
		@throw [NSException exceptionWithName:NSInvalidArgumentException
																	 reason:@"Trying to write data in an unsafe place" userInfo:nil];
#endif
	
	OSWriteBigInt32(buffer, 1, vmaddr);
	buffer[5] = length;
	/* append data */
	memcpy(buffer + 6, data, length);
	
	return [self sendCommand:buffer length:22 context:ctxt];	
}

- (IOReturn)readDataAtAddress:(user_addr_t)address space:(WKAddressSpace)space length:(size_t)length request:(NSUInteger)request {
	uint8_t buffer[7];
	bzero(buffer, 7);
	
	buffer[0] = WKOutputReportReadMemory;
	/* write address and size in big endian */
	OSWriteBigInt32(buffer, 1, __WiiRemoteTranslateAddress(address, space));
	OSWriteBigInt16(buffer, 5, length);
	
	IOReturn err = [self sendCommand:buffer length:7 context:nil];
	if (kIOReturnSuccess == err)
		wk_requests = __WKReadRequestPush(wk_requests, request);
	
	return err;
}

#pragma mark Extension
- (IOReturn)initializeExtension {
	if (!wk_wiiFlags.initializing) {
		wk_wiiFlags.initializing = 1;
		return [self writeData:(const uint8_t []){ 0x00 } length:1 atAddress:EXTENSION_REGISTER_STATUS space:kWKMemorySpaceExtension context:(void *)(intptr_t)200];
	}
	return kIOReturnSuccess;
}

- (void)setExtension:(WKExtension *)anExtension {
	if (anExtension != wk_extension) {
		[wk_extension release];
		wk_extension = [anExtension retain];
		[wk_extension setWiiRemote:self];
	}
}

- (void)setExtensionType:(WKExtensionType)type {
	if ([wk_extension type] != type) {
		if (type != kWKExtensionNone)
			[self setExtension:[WKExtension extensionWithType:type]];
		else
			[self setExtension:nil];
		
		if ([self irMode] != kWKIRModeOff) {
			[self setIrMode:exp != kWKExtensionNone ? kWKIRModeBasic : kWKIRModeExtended];
		}
		
		[self updateReportMode];
		WKLog(@"TODO: notify extension did change");
	}
}

- (void)didReceiveAck:(const uint8_t *)ack {
	switch (ack[0]) {
		case WKOutputReportMode:
			WKLog(@"did change report mode: %#hhx", ack[1]);
			break;		
		case WKOutputReportWriteMemory:
			WKLog(@"did write data: %#hhx", ack[1]);
			break;
		default:
			WKLog(@"did do something but don't know what: %#hx", ack);
			break;
	}
}

@end
