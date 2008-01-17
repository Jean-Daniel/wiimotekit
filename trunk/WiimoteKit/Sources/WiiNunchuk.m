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
		WKLog(@"TODO: Notify nunchuk C button change");
	}
	
	button = (buttons & 0x01) == 0;
	if (wk_wnFlags.z != button) {
		wk_wnFlags.z = button;
		WKLog(@"TODO: Notify nunchuk Z button change");
	}
	
	/* Joystick */
	uint8_t rawx, rawy;
	rawx = WII_DECRYPT(memory[0]);
	rawy = WII_DECRYPT(memory[1]);
	if (rawx != wk_rawX || rawy != wk_rawY) {
		wk_rawX = rawx;
		wk_rawY = rawy;
		
		if(wk_calib.x.max)
			wk_x = (CGFloat)(wk_rawX - wk_calib.x.center) / (wk_calib.x.max - wk_calib.x.min);
		if(wk_calib.y.max)
			wk_y = (CGFloat)(wk_rawY - wk_calib.y.center) / (wk_calib.y.max - wk_calib.y.min);
		WKLog(@"TODO: Notify nunchuk joystick change");
	}
	
	/* Accelerometer */
	uint8_t accx, accy, accz;
	accx = WII_DECRYPT(memory[2]);
	accy = WII_DECRYPT(memory[3]);
	accz = WII_DECRYPT(memory[4]);
	if (accx != wk_acc.rawX || accy != wk_acc.rawY || accz != wk_acc.rawZ) {
		wk_acc.rawX = accx;
		wk_acc.rawY = accy;
		wk_acc.rawZ = accz;
		
		/* compute calibrated values */
		if (wk_calib.acc.x0)
			wk_acc.x = (CGFloat)(wk_acc.rawX - wk_calib.acc.x0) / (wk_calib.acc.xG - wk_calib.acc.x0);
		if (wk_calib.acc.y0)
			wk_acc.y = (CGFloat)(wk_acc.rawY - wk_calib.acc.y0) / (wk_calib.acc.yG - wk_calib.acc.y0);
		if (wk_calib.acc.z0)
			wk_acc.z = (CGFloat)(wk_acc.rawZ - wk_calib.acc.z0) / (wk_calib.acc.zG - wk_calib.acc.z0);
		WKLog(@"TODO: Notify nunchuk position change");
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
