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

- (IOReturn)sendCommand:(const uint8_t *)cmd length:(size_t)length {
	NSParameterAssert(length <= 22);
	uint8_t buffer[23];
	bzero(buffer, 23);
	
	buffer[0] = 0x52; /* magic number (HID spec) */
	memcpy(buffer + 1, cmd, length);
	if ([self isRumbleEnabled]) buffer[2] |= 1; // rumble bit must be set in all control report.
	
	WKLog(@"=> Send command %#x (cmd[1]: %#x,  cmd[2]: %#x)", cmd[0], length > 1 ? cmd[1] : 0, length > 2 ? cmd[2] : 0);
	return [[self connection] sendData:buffer length:length + 1 context:nil];
}

- (IOReturn)readDataAtAddress:(user_addr_t)address space:(WKAddressSpace)space length:(size_t)length handler:(SEL)handler {
	uint8_t buffer[7];
	bzero(buffer, 7);
	
	buffer[0] = WKOutputReportReadMemory;
	/* write address and size in big endian */
	OSWriteBigInt32(buffer, 1, __WiiRemoteTranslateAddress(address, space));
	OSWriteBigInt16(buffer, 5, length);
	
	IOReturn err = [self sendCommand:buffer length:7];
	if (kIOReturnSuccess == err) {
		// null array callback is what we need for integer array
		if (!wk_rRequests) wk_rRequests = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
		CFArrayAppendValue(wk_rRequests, handler);
	}
	return err;
}

- (IOReturn)writeData:(const uint8_t *)data length:(size_t)length atAddress:(user_addr_t)address space:(WKAddressSpace)space next:(SEL)next {
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
	
	IOReturn err = [self sendCommand:buffer length:22];
	if (kIOReturnSuccess == err) {
		// null array callback is what we need for integer array
		if (!wk_wRequests) wk_wRequests = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
		CFArrayAppendValue(wk_wRequests, next);
	}
	return err;
}

#pragma mark Extension
- (IOReturn)initializeExtension {
	if (!wk_wiiFlags.initializing) {
		wk_wiiFlags.initializing = 1;
		return [self writeData:(const uint8_t []){ 0x00 } length:1 atAddress:EXTENSION_REGISTER_STATUS 
										 space:kWKMemorySpaceExtension next:@selector(didInitializeExtension:)];
	}
	return kIOReturnSuccess;
}
- (void)didInitializeExtension:(NSUInteger)status {
	// don't know what the param status contains (see 0x22 report for details) ?
	[self readDataAtAddress:EXTENSION_REGISTER_TYPE space:kWKMemorySpaceExtension length:2 handler:@selector(handleExtensionType:length:)]; // read expansion device type	
}

- (void)handleExtensionType:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length == 2);
	uint16_t wiitype = OSReadBigInt16(data, 0);
	WKExtensionType type = kWKExtensionNone;
	/* set extension type */
	switch (wiitype) {
		case 0xfefe:
			type = kWKExtensionNunchuk;
			break;
		case 0xfdfd:
			type = kWKExtensionClassicController;
			break;
		case 0xffff:
			WKLog(@"TODO: report extension error: unplug and try again");
			// maybe we should retry
			break;
		default:
			WKLog(@"TODO: report unsupported extension");
			break;
	}
	[self setExtensionType:type];
	wk_wiiFlags.initializing = 0;
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
		
		[self refreshReportMode];
		WKLog(@"TODO: notify extension did change");
	}
}

- (void)didReceiveAck:(const uint8_t *)ack {
	switch (ack[0]) {
		case WKOutputReportMode:
			WKLog(@"did change report mode: %#hhx", ack[1]);
			break;		
		case WKOutputReportWriteMemory: {
			NSAssert(wk_wRequests && CFArrayGetCount(wk_wRequests) > 0, @"Inconsistent write requests queue");
			SEL action = (SEL)CFArrayGetValueAtIndex(wk_wRequests, 0);
			CFArrayRemoveValueAtIndex(wk_wRequests, 0);
			// do not want to bother with NSInvocation, so just call the message directly.
			if (action) 
				(void)objc_msgSend(self, action, (NSUInteger)ack[1]);
		}
			break;
		default:
			WKLog(@"did do something but don't know what: %#hx", ack);
			break;
	}
}


#pragma mark Refresh
- (IOReturn)refreshStatus {
	if (wk_wiiFlags.inTransaction) {
	  wk_wiiFlags.status = 1;
		return kIOReturnSuccess;
	} else {
		uint8_t cmd[] = {0x15, 0x00};
		return [self sendCommand:cmd length:2];
	}
}

- (IOReturn)refreshReportMode {
	IOReturn err = kIOReturnSuccess;
	if (wk_wiiFlags.inTransaction) {
		wk_wiiFlags.reportMode = 1;
	} else {
		/* update report mode */
		uint8_t cmd[] = {WKOutputReportMode, 0x02, 0x30}; // Just buttons.
		
		if (wk_wiiFlags.continuous) cmd[1] = 0x04;
		
		/* wiimote accelerometer */
		if (wk_wiiFlags.accelerometer) {
			if (wk_extension && wk_irState.mode != kWKIRModeOff) {
				cmd[2] = kWKInputReportAll;
			} else if (wk_extension) {
				cmd[2] = kWKInputReportAccelerometerExtension;
			} else {
				cmd[2] = kWKInputReportAccelerometer;
			}
		} else if (wk_irState.mode != kWKIRModeOff) {
			if (wk_extension) {
				cmd[2] = kWKInputReportIRExtension;
			} else {
				/* IR only does not exists (and does not have sense) */
				cmd[2] = kWKInputReportAccelerometerIR;
			}
		} else if (wk_extension) {
			cmd[2] = kWKInputReportExtension;
		}
		err = [self sendCommand:cmd length:3];
	}
	return err;
}

- (IOReturn)refreshCalibration {
	return [self readDataAtAddress:0x16 space:kWKMemorySpaceWiiRemote length:8 handler:@selector(handleCalibration:length:)];
}
- (void)handleCalibration:(const uint8_t *)data length:(size_t)length {
#if defined(NINE_BITS_ACCELEROMETER)
	wk_accCalib.x0 = data[0] << 1;
	wk_accCalib.y0 = data[1] << 1;
	wk_accCalib.z0 = data[2] << 1;
	wk_accCalib.xG = data[4] << 1;
	wk_accCalib.yG = data[5] << 1;
	wk_accCalib.zG = data[6] << 1;
#else
	wk_accCalib.x0 = data[0];
	wk_accCalib.y0 = data[1];
	wk_accCalib.z0 = data[2];
	wk_accCalib.xG = data[4];
	wk_accCalib.yG = data[5];
	wk_accCalib.zG = data[6];
#endif	
}

- (IOReturn)refreshExtensionCalibration {
	size_t length = [[self extension] calibrationLength];
	user_addr_t addr = [[self extension] calibrationAddress];
	if (addr == 0 || length == 0) return kIOReturnSuccess;
	
	return [self readDataAtAddress:addr space:kWKMemorySpaceExtension 
													length:length handler:@selector(handleExtensionCalibration:length:)];
}

- (void)handleExtensionCalibration:(const uint8_t *)data length:(size_t)length {
	[[self extension] parseCalibration:data length:length];
}

#pragma mark IR Camera
- (WKIRMode)irMode {
	return wk_irState.mode;
}
- (IOReturn)setIrMode:(WKIRMode)aMode {
	if (aMode != wk_irState.mode) {
		if (aMode == kWKIRModeOff) {
			[self sendCommand:(const uint8_t[]){ WKOutputReportIRCamera, 0x00 } length:2];
			[self sendCommand:(const uint8_t[]){ WKOutputReportIRCamera2, 0x00 } length:2];
		} else {
			/* if was previously off, we have to start it */
			if (wk_irState.mode == kWKIRModeOff) {
				/* start ir sensor */
				[self sendCommand:(const uint8_t[]){ WKOutputReportIRCamera, 0x04 } length:2];
				[self sendCommand:(const uint8_t[]){ WKOutputReportIRCamera2, 0x04 } length:2];
				[self writeData:(const uint8_t[]){ 0x01 } length:1 atAddress:IR_REGISTER_STATUS 
									space:kWKMemorySpaceIRCamera next:@selector(didStartIRCamera:)];
				/* following operation are done in the data send callback */
			}  else {
				/* set mode */
				[self writeData:(const uint8_t[]){ aMode } length:1 atAddress:IR_REGISTER_MODE space:kWKMemorySpaceIRCamera next:nil];
			}
		}
		wk_irState.mode = aMode;
		[self refreshReportMode];
	}
	return kIOReturnSuccess;
}

- (void)didStartIRCamera:(NSUInteger)status {
	[self writeData:(const uint8_t[]){ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x00, 0xc0 } length:9 
				atAddress:IR_REGISTER_SENSITIVITY_1  space:kWKMemorySpaceIRCamera next:@selector(didSetIRCameraSensibilityOne:)];	
}
- (void)didSetIRCameraSensibilityOne:(NSUInteger)status {
	[self writeData:(const uint8_t[]){ 0x40, 0x00 } length:2 atAddress:IR_REGISTER_SENSITIVITY_2  
						space:kWKMemorySpaceIRCamera next:@selector(didSetIRCameraSensibilityTwo:)];	
}
- (void)didSetIRCameraSensibilityTwo:(NSUInteger)status {
	[self writeData:(const uint8_t[]){ 0x08 } length:1 atAddress:IR_REGISTER_STATUS
						space:kWKMemorySpaceIRCamera next:@selector(didSetIRCameraStatus:)];	
}
- (void)didSetIRCameraStatus:(NSUInteger)status {
	[self writeData:(const uint8_t[]){ wk_irState.mode } length:1 atAddress:IR_REGISTER_MODE
						space:kWKMemorySpaceIRCamera next:nil];	
}


@end
