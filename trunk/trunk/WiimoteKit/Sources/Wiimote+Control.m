//
//  WiiRemote+Control.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 13/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import "WiiRemoteInternal.h"

#import <WiimoteKit/WiimoteKit.h>
#import <WiimoteKit/WKExtension.h>
#import <WiimoteKit/WKConnection.h>

typedef const uint8_t WKWiiCmd[];

#pragma mark -
@implementation WiiRemote (WKControlLink)


- (IOReturn)sendCommand:(const uint8_t *)cmd length:(size_t)length {
	return [self sendCommand:cmd length:length context:nil];
}

#pragma mark -
- (IOReturn)updateReportMode {
	IOReturn err = kIOReturnSuccess;
	if (wk_wiiFlags.inTransaction) {
		wk_wiiFlags.reportMode = 1;
	} else {
		/* update report mode */
		uint8_t cmd[] = {WKOutputReportMode, 0x02, 0x30}; // Just buttons.
		
		if (wk_wiiFlags.continuous) cmd[1] = 0x04;
		
		/* wiimote accelerometer */
		if (wk_wiiFlags.accelerometer) cmd[2] |= 1;
		/* IR sensor */
		if (irState.mode != kWKIRModeOff) cmd[2] |= 2;
		/* extension */
		if (wk_extension) cmd[2] |= 4;
		err = [self sendCommand:cmd length:3];
	}
	return err;
}

- (IOReturn)setRumbleEnabled:(BOOL)rumble {
	IOReturn err = kIOReturnSuccess;
	/* canonize bool */
	NSUInteger flag = rumble ? 1 : 0;
	if (flag != wk_wiiFlags.rumble) {
		wk_wiiFlags.rumble = flag;
		/* send a message to apply change */
		err = [self refreshStatus];
		/* TODO: notify delegate */
	}
	return err;
}

- (IOReturn)setLeds:(WKLEDState)leds {
	IOReturn err = kIOReturnSuccess;
	leds &= 0xf;
	if (wk_wiiFlags.leds != leds) {
		uint8_t cmd[] = { WKOutputReportLEDs, leds << 4 };
		err = [self sendCommand:cmd length:2];
		wk_wiiFlags.leds = leds;
		WKLog(@"TODO: leds state did change");
//		if (kIOReturnSuccess == err)
//			[self refreshStatus]; // will send a led did change notification
	}
	return err;
}

- (void)setContinuous:(BOOL)value {
	bool flag = value ? 1 : 0;
	if (wk_wiiFlags.continuous != flag) {
		wk_wiiFlags.continuous = flag;
		[self updateReportMode];
	}
}
- (void)setAcceptsAccelerometerEvents:(BOOL)accept {
	bool flag = accept ? 1 : 0;
	if (wk_wiiFlags.accelerometer != flag) {
		wk_wiiFlags.accelerometer = flag;
		[self updateReportMode];
	}
}

#pragma mark IR
- (WKIRMode)irMode {
	return irState.mode;
}
- (IOReturn)setIrMode:(WKIRMode)aMode {
	if (aMode != irState.mode) {
		if (aMode == kWKIRModeOff) {
			[self sendCommand:(WKWiiCmd){ WKOutputReportIRCamera, 0x00 } length:2];
			[self sendCommand:(WKWiiCmd){ WKOutputReportIRCamera2, 0x00 } length:2];
		} else {
			/* if was previously off, we have to start it */
			if (irState.mode == kWKIRModeOff) {
				/* start ir sensor */
				[self sendCommand:(WKWiiCmd){ WKOutputReportIRCamera, 0x04 } length:2];
				[self sendCommand:(WKWiiCmd){ WKOutputReportIRCamera2, 0x04 } length:2 context:(void *)100];
				/* following operation are done in the data send callback */
			}  else {
				/* set mode */
				[self writeData:(WKWiiCmd){ aMode } length:1 atAddress:IR_REGISTER_MODE space:kWKMemorySpaceIRCamera context:nil];
			}
		}
		irState.mode = aMode;
		[self updateReportMode];
	}
	return kIOReturnSuccess;
}

- (IOReturn)setIREnabled:(BOOL)enabled {
	IOReturn err = kIOReturnSuccess;
	if (!enabled && irState.mode != kWKIRModeOff) {
		err = [self setIrMode:kWKIRModeOff];
	} else if (enabled && irState.mode == kWKIRModeOff) {
		if (!wk_extension)
			err = [self setIrMode:kWKIRModeExtended];
		else
			err = [self setIrMode:kWKIRModeBasic];
	}
	return err;
}

- (IOReturn)refreshStatus {
	if (wk_wiiFlags.inTransaction) {
	  wk_wiiFlags.status = 1;
		return kIOReturnSuccess;
	} else {
		uint8_t cmd[] = {0x15, 0x00};
		return [self sendCommand:cmd length:2];
	}
}
- (IOReturn)refreshCalibration {
	return [self readDataAtAddress:0x16 space:kWKMemorySpaceWiiRemote length:8 request:kWKWiiRemoteCalibrationRequest];
}


#pragma mark -
- (IOReturn)refreshExtensionCalibration {
	size_t length = [[self extension] calibrationLength];
	user_addr_t addr = [[self extension] calibrationAddress];
	if (addr == 0 || length == 0) return kIOReturnSuccess;
	
	return [self readDataAtAddress:addr space:kWKMemorySpaceExtension length:length request:kWKExtensionCalibrationRequest];
}

#pragma mark -
- (void)connection:(WKConnection *)aConnection didSendData:(void *)ctxt error:(IOReturn)status {
	switch ((intptr_t)ctxt) {
			/* IR Initialization (100) */
		case 100:
			// initialize IR: step 1 
			[self writeData:(WKWiiCmd){ 0x01 } length:1 atAddress:IR_REGISTER_STATUS space:kWKMemorySpaceIRCamera context:(void *)101];
			break;
		case 101:
			// initialize IR: step 2
			[self writeData:(WKWiiCmd){ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x00, 0xc0 } length:9 atAddress:IR_REGISTER_SENSITIVITY_1  space:kWKMemorySpaceIRCamera context:(void *)102];
			break;
		case 102:
			// initialize IR: step 3
			[self writeData:(WKWiiCmd){ 0x40, 0x00 } length:2 atAddress:IR_REGISTER_SENSITIVITY_2  space:kWKMemorySpaceIRCamera context:(void *)103];
			break;
		case 103:
			// initialize IR: step 4
			[self writeData:(WKWiiCmd){ 0x08 } length:1 atAddress:IR_REGISTER_STATUS  space:kWKMemorySpaceIRCamera context:(void *)104];
			break;
		case 104:
			// initialize IR: step 5, set mode
			[self writeData:(WKWiiCmd){ irState.mode } length:1 atAddress:IR_REGISTER_MODE space:kWKMemorySpaceIRCamera context:nil];
			break;
			/* Extension initialization (200) */
		case 200:
			// initialize extension: request extension type
			[self readDataAtAddress:EXTENSION_REGISTER_TYPE space:kWKMemorySpaceExtension length:2 request:kWKExtensionTypeRequest]; // read expansion device type
			break;
	}
}


@end
