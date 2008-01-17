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

- (WKLEDState)leds {
	return wk_wiiFlags.leds;
}

- (CGFloat)battery {
	/* maximum level is 0xc */
	return wk_wiiFlags.battery / (CGFloat)0xc;
}

- (BOOL)isIREnabled {
	return [self irMode] != kWKIRModeOff;
}
- (BOOL)isRumbleEnabled {
	return wk_wiiFlags.rumble;
}

- (BOOL)isContinuous {
	return wk_wiiFlags.continuous;
}
- (BOOL)acceptsAccelerometerEvents {
	return wk_wiiFlags.accelerometer;
}

- (WKExtension *)extension {
	return wk_extension;
}

@end

#if 0

// <summary>
// Parse IR data from report
// </summary>
// <param name="buff">Data buffer</param>
private void ParseIR(byte[] buff)
{
	mWiimoteState.IRState.RawX1 = buff[6]  | ((buff[8] >> 4) & 0x03) << 8;
	mWiimoteState.IRState.RawY1 = buff[7]  | ((buff[8] >> 6) & 0x03) << 8;
	
	switch(mWiimoteState.IRState.Mode)
	{
		case IRMode.Basic:
			mWiimoteState.IRState.RawX2 = buff[9]  | ((buff[8] >> 0) & 0x03) << 8;
			mWiimoteState.IRState.RawY2 = buff[10] | ((buff[8] >> 2) & 0x03) << 8;
			
			mWiimoteState.IRState.Size1 = 0x00;
			mWiimoteState.IRState.Size2 = 0x00;
			
			mWiimoteState.IRState.Found1 = !(buff[6] == 0xff && buff[7] == 0xff);
			mWiimoteState.IRState.Found2 = !(buff[9] == 0xff && buff[10] == 0xff);
			break;
		case IRMode.Extended:
			mWiimoteState.IRState.RawX2 = buff[9]  | ((buff[11] >> 4) & 0x03) << 8;
			mWiimoteState.IRState.RawY2 = buff[10] | ((buff[11] >> 6) & 0x03) << 8;
			
			mWiimoteState.IRState.Size1 = buff[8] & 0x0f;
			mWiimoteState.IRState.Size2 = buff[11] & 0x0f;
			
			mWiimoteState.IRState.Found1 = !(buff[6] == 0xff && buff[7] == 0xff && buff[8] == 0xff);
			mWiimoteState.IRState.Found2 = !(buff[9] == 0xff && buff[10] == 0xff && buff[11] == 0xff);
			
			//a guess based on the structure of the 1st 2 dots
			mWiimoteState.IRState.RawX3 = buff[12] | ((buff[14] >> 4) & 0x03) << 8;
			mWiimoteState.IRState.RawY3 = buff[13] | ((buff[14] >> 6) & 0x03) << 8;
			mWiimoteState.IRState.Size3 = buff[14] & 0x0f;
			mWiimoteState.IRState.Found3 = !(buff[12] == 0xff && buff[13] == 0xff && buff[14] == 0xff);
			
			mWiimoteState.IRState.RawX4 = buff[15] | ((buff[17] >> 4) & 0x03) << 8;
			mWiimoteState.IRState.RawY4 = buff[16] | ((buff[17] >> 6) & 0x03) << 8;
			mWiimoteState.IRState.Size4 = buff[17] & 0x0f;
			mWiimoteState.IRState.Found4 = !(buff[15] == 0xff && buff[16] == 0xff && buff[17] == 0xff);
			
			break;
	}
	
	mWiimoteState.IRState.X1 = (float)(mWiimoteState.IRState.RawX1 / 1023.5f);
	mWiimoteState.IRState.X2 = (float)(mWiimoteState.IRState.RawX2 / 1023.5f);
	mWiimoteState.IRState.X3 = (float)(mWiimoteState.IRState.RawX3 / 1023.5f);
	mWiimoteState.IRState.X4 = (float)(mWiimoteState.IRState.RawX4 / 1023.5f);
	mWiimoteState.IRState.Y1 = (float)(mWiimoteState.IRState.RawY1 / 767.5f);
	mWiimoteState.IRState.Y2 = (float)(mWiimoteState.IRState.RawY2 / 767.5f);
	mWiimoteState.IRState.Y3 = (float)(mWiimoteState.IRState.RawY3 / 767.5f);
	mWiimoteState.IRState.Y4 = (float)(mWiimoteState.IRState.RawY4 / 767.5f);
	
	if(mWiimoteState.IRState.Found1 && mWiimoteState.IRState.Found2)
	{
		mWiimoteState.IRState.RawMidX = (mWiimoteState.IRState.RawX2 + mWiimoteState.IRState.RawX1) / 2;
		mWiimoteState.IRState.RawMidY = (mWiimoteState.IRState.RawY2 + mWiimoteState.IRState.RawY1) / 2;
		
		mWiimoteState.IRState.MidX = (mWiimoteState.IRState.X2 + mWiimoteState.IRState.X1) / 2.0f;
		mWiimoteState.IRState.MidY = (mWiimoteState.IRState.Y2 + mWiimoteState.IRState.Y1) / 2.0f;
	}
	else
		mWiimoteState.IRState.MidX = mWiimoteState.IRState.MidY = 0.0f;
}


#endif
