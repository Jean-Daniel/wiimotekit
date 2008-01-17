//
//  WiiClassic.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 16/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import "WiiClassic.h"
#import "WiiRemoteInternal.h"

@implementation WiiClassic

- (WKExtensionType)type {
	return kWKExtensionClassicController;
}

- (void)parseStatus:(const uint8_t *)data range:(NSRange)aRange {
	NSParameterAssert(aRange.length >= 6);
	
	WKClassicButtonsState buttons = ((WII_DECRYPT(data[4]) << 8) + WII_DECRYPT(data[5]));
	/* stats is negative, so use ~buttons */
	buttons = ~buttons & kWKClassicButtonsMask;
	if (buttons != wk_buttons) {
		wk_buttons = buttons;
		// TODO: compute delta
		WKLog(@"TODO: Notify classic buttons change");
	}
	
	uint8_t tmp[] = { WII_DECRYPT(data[0]), WII_DECRYPT(data[1]), WII_DECRYPT(data[2]) };
	
	uint8_t x, y;
	/* left joystick */
	x = tmp[0] & 0x3f;
	y = tmp[1] & 0x3f;
	if (x != wk_rawXL || y != wk_rawYL) {
		wk_rawXL = x;
		wk_rawYL = y;
		
		/* compute calibrated values */
		if(wk_calib.xl.max)
			wk_xl = (CGFloat)(wk_rawXL - wk_calib.xl.center) / 
			(wk_calib.xl.max - wk_calib.xl.min);
		if(wk_calib.yl.max)
			wk_yl = (CGFloat)(wk_rawYL - wk_calib.yl.center) / 
			(wk_calib.yl.max - wk_calib.yl.min);
		
		WKLog(@"TODO: Notify classic left joystick change");
	}
	
	/* right joystick */
	x = (((tmp[0] & 0xc0) >> 3) | ((tmp[1] & 0xc0) >> 5) | ((tmp[2] & 0x80) >> 7)) & 0x1f;
	y = tmp[2] & 0x1f;
	if (x != wk_rawXR || y != wk_rawYR) {
		wk_rawXR = x;
		wk_rawYR = y;
		
		/* compute calibrated values */
		if(wk_calib.xr.max)
			wk_xr = (CGFloat)(wk_rawXR - wk_calib.xr.center) / 
			(wk_calib.xr.max - wk_calib.xr.min);
		if(wk_calib.yr.max)
			wk_yr = (CGFloat)(wk_rawYR - wk_calib.yr.center) / 
			(wk_calib.yr.max - wk_calib.yr.min);
		
		WKLog(@"TODO: Notify classic right joystick change");
	}
	
	/* L and R */
	uint8_t value;			
	value = (((tmp[2] & 0x60) >> 2) | (tmp[3] >> 5)) & 0x1f;
	if (value != wk_rawTL) {
		wk_rawTL = value;
		
		/* compute calibrated values */
		if(wk_calib.tl.max)
			wk_tl = (CGFloat)wk_rawTL / 
			(wk_calib.tl.max - wk_calib.tl.min);
		
		WKLog(@"TODO: Notify classic L Button change");
	}
	
	value = tmp[3] & 0x1f;
	if (value != wk_rawTR) {
		wk_rawTR = value;
		
		if(wk_calib.tr.max)
			wk_tr = (CGFloat)wk_rawTR / 
			(wk_calib.tr.max - wk_calib.tr.min);				
		
		WKLog(@"TODO: Notify classic R Button change");
	}
}

- (void)parseCalibration:(const uint8_t *)memory length:(size_t)length {
	// classic controller calibration data
	wk_calib.xl.max    = WII_DECRYPT(memory[0]) >> 2;
	wk_calib.xl.min    = WII_DECRYPT(memory[1]) >> 2;
	wk_calib.xl.center = WII_DECRYPT(memory[2]) >> 2;
	
	wk_calib.yl.max    = WII_DECRYPT(memory[3]) >> 2;
	wk_calib.yl.min    = WII_DECRYPT(memory[4]) >> 2;
	wk_calib.yl.center = WII_DECRYPT(memory[5]) >> 2;
	
	wk_calib.xr.max    = WII_DECRYPT(memory[6]) >> 3;
	wk_calib.xr.min    = WII_DECRYPT(memory[7]) >> 3;
	wk_calib.xr.center = WII_DECRYPT(memory[8]) >> 3;
	
	wk_calib.yr.max    = WII_DECRYPT(memory[9])  >> 3;
	wk_calib.yr.min    = WII_DECRYPT(memory[10]) >> 3;
	wk_calib.yr.center = WII_DECRYPT(memory[11]) >> 3;
	
	// this doesn't seem right...
	//			wk_calib.tl.max = WII_DECRYPT(memory[12]) >> 3;
	//			wk_calib.tl.min = WII_DECRYPT(memory[13]) >> 3;
	//			wk_calib.tr.max = WII_DECRYPT(memory[14]) >> 3;
	//			wk_calib.tr.min = WII_DECRYPT(memory[15]) >> 3;
	wk_calib.tl.max = 31;
	wk_calib.tl.min = 0;
	wk_calib.tr.max = 31;
	wk_calib.tr.min = 0;
}

#pragma mark Calibration
- (size_t)calibrationLength {
	return 16;
}

- (user_addr_t)calibrationAddress {
	return EXTENSION_REGISTER_CALIBRATION;
}

@end
