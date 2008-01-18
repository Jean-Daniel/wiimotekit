//
//  Wiimote.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 12/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import <WiimoteKit/WiiRemote.h>
#import "WiiRemoteInternal.h"

#import <WiimoteKit/WiimoteKit.h>
#import <WiimoteKit/WKExtension.h>
#import <WiimoteKit/WKConnection.h>

#import <IOBluetooth/objc/IOBluetoothDevice.h>

@implementation WiiRemote

- (id)initWithDevice:(IOBluetoothDevice *)aDevice {
	if (self = [super init]) {
		wk_connection = [[WKConnection alloc] initWithDevice:aDevice];
		if (!wk_connection) {
			[self release];
			self = nil;
		} else {
			/* default value */
			wk_wiiFlags.leds = 0x1f;
			
			[wk_connection setDelegate:self];
			[wk_connection connect];
		}
	}
	return self;
}

- (void)dealloc {
	[wk_extension setWiiRemote:nil];
	[wk_extension release];
	
	[wk_connection setDelegate:nil];
	[wk_connection close];
	[wk_connection release];
	
	if (wk_rRequests) CFRelease(wk_rRequests);
	if (wk_wRequests) CFRelease(wk_wRequests);
	[wk_buffer release];
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@ %p> { %@: %@ }", 
					[self class], self, [[wk_connection device] getName], [self address]];
}

#pragma mark -
- (NSString *)address {
	return [[wk_connection device] getAddressString];
}

- (BOOL)isConnected {
	return wk_connection != nil;
}
- (WKConnection *)connection {
	return wk_connection;
}

- (void)connectionDidOpen:(WKConnection *)aConnection {
	WKLog(@"TODO: notify %@ connected", self);
	/* turn off all leds */
	[self setLeds:0];
	/* get status */
	[self refreshStatus];
	/* request wiimote calibration */
	[self refreshCalibration];
}

- (BOOL)isContinuous {
	return wk_wiiFlags.continuous;
}
- (void)setContinuous:(BOOL)value {
	bool flag = value ? 1 : 0;
	if (wk_wiiFlags.continuous != flag) {
		wk_wiiFlags.continuous = flag;
		[self refreshReportMode];
	}
}

- (BOOL)acceptsIRCameraEvents {
	return [self irMode] != kWKIRModeOff;
}

- (void)setAcceptsIRCameraEvents:(BOOL)flag {
	IOReturn err = kIOReturnSuccess;
	if (!flag && wk_irState.mode != kWKIRModeOff) {
		err = [self setIrMode:kWKIRModeOff];
	} else if (flag && wk_irState.mode == kWKIRModeOff) {
		if (!wk_extension)
			err = [self setIrMode:kWKIRModeExtended];
		else
			err = [self setIrMode:kWKIRModeBasic];
	}
	WKPrintIOReturn(err, "setAcceptsIRCameraEvents");
}

- (BOOL)acceptsAccelerometerEvents {
	return wk_wiiFlags.accelerometer;
}
- (void)setAcceptsAccelerometerEvents:(BOOL)accept {
	bool flag = accept ? 1 : 0;
	if (wk_wiiFlags.accelerometer != flag) {
		wk_wiiFlags.accelerometer = flag;
		[self refreshReportMode];
	}
}

@end
