//
//  WiiNunchuk.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 15/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import "WiiNunchuk.h"
#import "WiiRemoteInternal.h"

@implementation WiiNunchuk

- (WKExtensionType)type {
	return kWKExtensionNunchuk;
}

- (void)parseStatus:(const uint8_t *)data range:(NSRange)aRange {
	NSParameterAssert(aRange.length >= 6);
	
	const uint8_t *memory = data + aRange.location;
	
	/* C and Z */
	uint8_t buttons = WII_DECRYPT(memory[5]);
	bool button = (buttons & 0x02) == 0;
	if (wk_wnFlags.c != button) {
		wk_wnFlags.c = button;
		[[self wiiRemote] sendButtonEvent:kWKNunchukButtonC subtype:kWKEventExtensionButton down:button];
	}
	
	button = (buttons & 0x01) == 0;
	if (wk_wnFlags.z != button) {
		wk_wnFlags.z = button;
		[[self wiiRemote] sendButtonEvent:kWKNunchukButtonZ subtype:kWKEventExtensionButton down:button];
	}
	
	/* Joystick */
	uint8_t rawx, rawy;
	rawx = WII_DECRYPT(memory[0]);
	rawy = WII_DECRYPT(memory[1]);
	if (rawx != wk_rawX || rawy != wk_rawY) {
		WKJoystickEventData event;
		bzero(&event, sizeof(event));
		event.rawx = rawx;
		event.rawy = rawy;
		
		event.rawdx = event.rawx - wk_rawX;
		event.rawdy = event.rawy - wk_rawY;
		
		if(wk_calib.x.max) {
			event.x = (CGFloat)(event.rawx - wk_calib.x.center) / (wk_calib.x.max - wk_calib.x.min);
			event.dx = event.x - wk_x;
		}
		if(wk_calib.y.max) {
			event.y = (CGFloat)(event.rawy - wk_calib.y.center) / (wk_calib.y.max - wk_calib.y.min);
			event.dy = event.y - wk_y;
		}
		
		wk_x = event.x;
		wk_y = event.y;
		
		wk_rawX = event.rawx;
		wk_rawY = event.rawy;
		
		[[self wiiRemote] sendJoystickEvent:&event subtype:0];
	}
	
	/* Accelerometer */
	WKAccelerometerEventData event;
	bzero(&event, sizeof(event));
	/* position */
	event.rawx = WII_DECRYPT(memory[2]);
	event.rawy = WII_DECRYPT(memory[3]);
	event.rawz = WII_DECRYPT(memory[4]);
	if (event.rawx != wk_acc.rawX || event.rawy != wk_acc.rawY || event.rawz != wk_acc.rawZ) {
		
		/* delta */
		event.rawdx = event.rawx - wk_acc.rawX;
		event.rawdy = event.rawy - wk_acc.rawY;
		event.rawdz = event.rawz - wk_acc.rawZ;		
		
		/* compute calibrated values */
		if (wk_calib.acc.x0) {
			event.x = (CGFloat)(event.rawx - wk_calib.acc.x0) / (wk_calib.acc.xG - wk_calib.acc.x0);
			event.dx = event.x - wk_acc.x;
		}
		if (wk_calib.acc.y0) {
			event.y = (CGFloat)(event.rawy - wk_calib.acc.y0) / (wk_calib.acc.yG - wk_calib.acc.y0);
			event.dy = event.y - wk_acc.y;
		}
		if (wk_calib.acc.z0) {
			event.z = (CGFloat)(event.rawz - wk_calib.acc.z0) / (wk_calib.acc.zG - wk_calib.acc.z0);
			event.dz = event.z - wk_acc.z;
		}
		
		wk_acc.x = event.x;
		wk_acc.y = event.y;
		wk_acc.z = event.z;
		
		wk_acc.rawX = event.rawx;
		wk_acc.rawY = event.rawy;
		wk_acc.rawZ = event.rawz;
		
		[[self wiiRemote] sendAccelerometerEvent:&event subtype:kWKEventExtensionAccelerometer];
	}
}

- (void)parseCalibration:(const uint8_t *)memory length:(size_t)length {
	wk_calib.acc.x0 = WII_DECRYPT(memory[0]);
	wk_calib.acc.y0 = WII_DECRYPT(memory[1]);
	wk_calib.acc.z0 = WII_DECRYPT(memory[2]);
	wk_calib.acc.xG = WII_DECRYPT(memory[4]);
	wk_calib.acc.yG = WII_DECRYPT(memory[5]);
	wk_calib.acc.zG = WII_DECRYPT(memory[6]);
	
	wk_calib.x.max    = WII_DECRYPT(memory[8]);
	wk_calib.x.min    = WII_DECRYPT(memory[9]);
	wk_calib.x.center = WII_DECRYPT(memory[10]);
	wk_calib.y.max    = WII_DECRYPT(memory[11]);
	wk_calib.y.min    = WII_DECRYPT(memory[12]);
	wk_calib.y.center = WII_DECRYPT(memory[13]);
}

#pragma mark Calibration
- (size_t)calibrationLength {
	return 16;
}

- (user_addr_t)calibrationAddress {
	return EXTENSION_REGISTER_CALIBRATION;
}

@end
