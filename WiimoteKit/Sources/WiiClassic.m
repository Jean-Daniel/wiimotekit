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
		for (NSUInteger idx = 0; idx < 16; idx++) {
			NSUInteger flag = 1 << idx;
			if (flag & kWKClassicButtonsMask) {
				/* xor */
				bool before = wk_buttons & flag;
				bool after = buttons & flag;
				if ((before && !after) || (!before && after)) {
					[[self wiiRemote] sendButtonEvent:flag subtype:kWKEventExtensionButton down:before];
				}
			}
		}
		wk_buttons = buttons;
	}
	
	uint8_t tmp[] = { WII_DECRYPT(data[0]), WII_DECRYPT(data[1]), WII_DECRYPT(data[2]) };
	
	WKJoystickEventData event;
	bzero(&event, sizeof(event));
	/* left joystick */
	event.rawx = tmp[0] & 0x3f;
	event.rawy = tmp[1] & 0x3f;
	if (event.rawx != wk_rawXL || event.rawy != wk_rawYL) {
		event.rawdx = event.rawx - wk_rawXL;
		event.rawdy = event.rawy - wk_rawYL;
		
		if(wk_calib.xl.max) {
			event.x = ((CGFloat)event.rawx - wk_calib.xl.center) / (wk_calib.xl.max - wk_calib.xl.min);
			event.dx = event.x - wk_xl;
		}
		if(wk_calib.yl.max) {
			event.y = ((CGFloat)event.rawy - wk_calib.yl.center) / (wk_calib.yl.max - wk_calib.yl.min);
			event.dy = event.y - wk_yl;
		}
		
		wk_xl = event.x;
		wk_yl = event.y;
		
		wk_rawXL = event.rawx;
		wk_rawYL = event.rawy;
		
		[[self wiiRemote] sendJoystickEvent:&event subtype:kWKEventRightJoystick];
	}
	
	/* right joystick */
	event.rawx = (((tmp[0] & 0xc0) >> 3) | ((tmp[1] & 0xc0) >> 5) | ((tmp[2] & 0x80) >> 7)) & 0x1f;
	event.rawy = tmp[2] & 0x1f;
	if (event.rawx != wk_rawXR || event.rawy != wk_rawYR) {
		event.rawdx = event.rawx - wk_rawXL;
		event.rawdy = event.rawy - wk_rawYL;
		
		if(wk_calib.xr.max) {
			event.x = ((CGFloat)event.rawx - wk_calib.xr.center) / (wk_calib.xr.max - wk_calib.xr.min);
			event.dx = event.x - wk_xr;
		}
		if(wk_calib.yr.max) {
			event.y = ((CGFloat)event.rawy - wk_calib.yr.center) / (wk_calib.yr.max - wk_calib.yr.min);
			event.dy = event.y - wk_yr;
		}
		
		wk_xr = event.x;
		wk_yr = event.y;
		
		wk_rawXR = event.rawx;
		wk_rawYR = event.rawy;
		
		[[self wiiRemote] sendJoystickEvent:&event subtype:kWKEventRightJoystick];
	}
	
	/* L and R */
	uint8_t value;			
	value = (((tmp[2] & 0x60) >> 2) | (tmp[3] >> 5)) & 0x1f;
	if (value != wk_rawTL) {
		WKAnalogEventData event;
		bzero(&event, sizeof(event));
		
		event.rawx = value;
		event.rawdx = event.rawx - wk_rawTL;
		
		/* compute calibrated values */
		if(wk_calib.tl.max) {
			event.x = (CGFloat)event.rawx / (wk_calib.tl.max - wk_calib.tl.min);
			event.dx = event.x - wk_tl;
		}
		
		wk_tl = event.x;
		wk_rawTL = event.rawx;
		
		[[self wiiRemote] sendAnalogEvent:&event subtype:kWKEventAnalogLeftButton];
	}
	
	value = tmp[3] & 0x1f;
	if (value != wk_rawTR) {
		WKAnalogEventData event;
		bzero(&event, sizeof(event));
		
		event.rawx = value;
		event.rawdx = event.rawx - wk_rawTR;
		
		/* compute calibrated values */
		if(wk_calib.tr.max) {
			event.x = (CGFloat)event.rawx / (wk_calib.tr.max - wk_calib.tr.min);
			event.dx = event.x - wk_tr;
		}
		
		wk_tr = event.x;
		wk_rawTR = event.rawx;
		
		[[self wiiRemote] sendAnalogEvent:&event subtype:kWKEventAnalogRightButton];
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
