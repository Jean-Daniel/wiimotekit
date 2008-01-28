//
//  WiiRemote+Interrupt.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 13/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import "WiiRemoteInternal.h"

#import <WiimoteKit/WiimoteKit.h>
#import <WiimoteKit/WKExtension.h>
#import <WiimoteKit/WKConnection.h>

#define kWiiIRPixelsWidth 1024.0
#define kWiiIRPixelsHeight 768.0

@interface WiiRemote (WiiRemoteInputParser)
- (void)parserWriteAck:(const uint8_t *)data length:(size_t)length;
- (void)parseButtons:(const uint8_t *)data length:(size_t)length;
- (void)parseStatus:(const uint8_t *)data length:(size_t)length;
- (void)parseRead:(const uint8_t *)data length:(size_t)length;

/* report */
- (void)parseAccelerometer:(const uint8_t *)data range:(NSRange)range;
- (void)parseIRCamera:(const uint8_t *)data range:(NSRange)range;

@end

@implementation WiiRemote (WiiRemoteInputParser)

- (void)parseButtons:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length >= 2);
	WKWiiRemoteButtonsState state = OSReadBigInt16(data, 0) & kWKWiiRemoteButtonsMask;
	if (state != wk_wiiFlags.remoteButtons) {
		for (NSUInteger idx = 0; idx < 16; idx++) {
			NSUInteger flag = 1 << idx;
			if (flag & kWKWiiRemoteButtonsMask) {
				/* xor */
				bool before = wk_wiiFlags.remoteButtons & flag;
				bool after = state & flag;
				if ((before && !after) || (!before && after)) {
					[self sendButtonEvent:flag subtype:kWKEventWiimoteButton down:before];
				}
			}
		}
		wk_wiiFlags.remoteButtons = state;
	}
}

- (void)parseStatus:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length == 4);
	
	bool plugged = (data[0] & 0x02) != 0;
	if (plugged && !wk_extension) {
		// self initialize extension and notify when we receive it's type.
		[self initializeExtension];
	} else if (!plugged && wk_extension) {
		// unplug extension
		[self setExtensionType:kWKExtensionNone];
	}
	
	bool speaker = (data[0] & 0x04) != 0;
	if (speaker != wk_wiiFlags.speaker) {
		wk_wiiFlags.speaker = speaker;
		[self sendStatusEvent:wk_wiiFlags.speaker subtype:kWKStatusEventSpeaker];
	}

	bool continuous = (data[0] & 0x08) != 0;
	if (continuous != wk_wiiFlags.continuous) {
		wk_wiiFlags.continuous = continuous;
		WKLog(@"TODO: Continuous status did change");
	}
	
	/* check leds */
	WKLEDState state = (data[0] >> 4) & 0xf;
	if (state != wk_wiiFlags.leds) {
		wk_wiiFlags.leds = state;
		[self sendStatusEvent:wk_wiiFlags.leds subtype:kWKStatusEventLights];
	}
	
	/* check battery level */
	uint8_t battery = data[3];
	if (battery != wk_wiiFlags.battery) {
		wk_wiiFlags.battery = battery;
		[self sendStatusEvent:wk_wiiFlags.battery subtype:kWKStatusEventBattery];
	}
}

- (void)didReceiveData:(const uint8_t *)data length:(size_t)length {
	NSAssert(wk_rRequests && CFArrayGetCount(wk_rRequests) > 0, @"inconsistent request queue");
	SEL handler = (SEL)CFArrayGetValueAtIndex(wk_rRequests, 0);
	CFArrayRemoveValueAtIndex(wk_rRequests, 0);
	if (handler)
		(void)objc_msgSend(self, handler, data, length);
	else
		WKLog(@"receive data but does not waiting something");
}

- (void)parseRead:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length == 19);
	// user_addr_t addr = OSReadBigInt16(data, 1);
	// const uint8_t *memory = data + 3;
	if(data[0] & 0x08) {
		WKLog(@"Error reading data from Wiimote: Bytes do not exist.");
	} else if(data[0] & 0x07) {
		WKLog(@"Error reading data from Wiimote: Attempt to read from write-only registers.");
	} else if (data[0] & 0x0f) {
		WKLog(@"Error reading data from Wiimote: undefined error %#x", (int)data[0]);
	} else {
		size_t size = (data[0] >> 4) + 1;
		NSAssert(wk_wiiFlags.expected <= (size + [wk_buffer length]), @"receive more data than requested");
		if (wk_wiiFlags.expected > 16) {
			/* multipart request */
			if (!wk_buffer) wk_buffer = [[NSMutableData alloc] init];
			[wk_buffer appendBytes:data + 3 length:size];
			/* if download completed */
			if ([wk_buffer length] == wk_wiiFlags.expected) {
				[self didReceiveData:[wk_buffer bytes] length:[wk_buffer length]];
				[wk_buffer setLength:0];
			}
		} else {
			[self didReceiveData:data + 3 length:size];
		}
	}
}

- (void)parseAccelerometer:(const uint8_t *)data range:(NSRange)range {
	NSParameterAssert(range.length == 3);
	
	WKAccelerometerEventData event;
	bzero(&event, sizeof(event));
#if defined(NINE_BITS_ACCELEROMETER)
	// cam: added 9th bit of resolution to the wii acceleration
	// see http://www.wiili.org/index.php/Talk:Wiimote#Remaining_button_state_bits
	uint16_t adjust = OSReadBigInt16(data, 0);
	
	event.rawx = (data[range.location] << 1) | (adjust & 0x0040) >> 6;
	event.rawy = (data[range.location + 1] << 1) | (adjust & 0x2000) >> 13;
	event.rawz = (data[range.location + 2] << 1) | (adjust & 0x4000) >> 14;
#else
	event.rawx = data[range.location];
	event.rawy = data[range.location + 1];
	event.rawz = data[range.location + 2];	
#endif
	
	if (event.rawx != wk_accState.rawX || event.rawy != wk_accState.rawY || event.rawz != wk_accState.rawZ) {
		/* delta */
		event.rawdx = event.rawx - wk_accState.rawX;
		event.rawdy = event.rawy - wk_accState.rawY;
		event.rawdz = event.rawz - wk_accState.rawZ;
	
		/* compute calibrated values */
		if (wk_accCalib.x0) {
			event.x = (CGFloat)(event.rawx - wk_accCalib.x0) / (wk_accCalib.xG - wk_accCalib.x0);
			event.dx = event.x - wk_accState.x;
		}
		if (wk_accCalib.y0) {
			event.y = (CGFloat)(event.rawy - wk_accCalib.y0) / (wk_accCalib.yG - wk_accCalib.y0);
			event.dy = event.y - wk_accState.y;
		}
		if (wk_accCalib.z0) {
			event.z = (CGFloat)(event.rawz - wk_accCalib.z0) / (wk_accCalib.zG - wk_accCalib.z0);
			event.dz = event.z - wk_accState.z;
		}
		
		wk_accState.x = event.x;
		wk_accState.y = event.y;
		wk_accState.z = event.z;
		
		wk_accState.rawX = event.rawx;
		wk_accState.rawY = event.rawy;
		wk_accState.rawZ = event.rawz;
		
		//		_lowZ = _lowZ * 0.9 + rawz * 0.1;
		//		_lowX = _lowX * 0.9 + rawx * 0.1;
		//		
		//		CGFloat absx = fabs(_lowX - WIR_HALFRANGE);
		//		CGFloat absz = fabs(_lowZ - WIR_HALFRANGE);
		//		
		//		if (orientation == 0 || orientation == 2) absx -= WIR_INTERVAL;
		//		if (orientation == 1 || orientation == 3) absz -= WIR_INTERVAL;
		//		
		//		if (absz >= absx) {
		//			if (absz > WIR_INTERVAL)
		//				orientation = (_lowZ > WIR_HALFRANGE) ? 0 : 2;
		//		} else {
		//			if (absx > WIR_INTERVAL)
		//				orientation = (_lowX > WIR_HALFRANGE) ? 3 : 1;
		//		}
		
		[self sendAccelerometerEvent:&event subtype:kWKEventWiimoteAccelerometer];
	}
}

- (void)parseIRCamera:(const uint8_t *)data range:(NSRange)range {
	NSLog(@"%@%lu", NSStringFromSelector(_cmd), (long)range.length);
	wk_irState.sensors[0].rawX = data[range.location]  | ((data[range.location + 2] >> 4) & 0x03) << 8;
	wk_irState.sensors[0].rawY = data[range.location + 1]  | ((data[range.location + 2] >> 6) & 0x03) << 8;
	
	switch(range.length) {
		case 10:
			wk_irState.sensors[1].rawX = data[range.location + 3]  | ((data[range.location + 2] >> 0) & 0x03) << 8;
			wk_irState.sensors[1].rawY = data[range.location + 4] | ((data[range.location + 2] >> 2) & 0x03) << 8;
			
			wk_irState.sensors[0].size = 0x00;
			wk_irState.sensors[1].size = 0x00;
			
			wk_irState.sensors[0].found = !(data[range.location] == 0xff && data[range.location + 1] == 0xff);
			wk_irState.sensors[1].found = !(data[range.location + 3] == 0xff && data[range.location + 4] == 0xff);
			break;
		case 12:
			wk_irState.sensors[1].rawX = data[9]  | ((data[11] >> 4) & 0x03) << 8;
			wk_irState.sensors[1].rawY = data[10] | ((data[11] >> 6) & 0x03) << 8;
			
			wk_irState.sensors[0].size = data[8] & 0x0f;
			wk_irState.sensors[1].size = data[11] & 0x0f;
			
			wk_irState.sensors[0].found = !(data[6] == 0xff && data[7] == 0xff && data[8] == 0xff);
			wk_irState.sensors[1].found = !(data[9] == 0xff && data[10] == 0xff && data[11] == 0xff);
			
			//a guess based on the structure of the 1st 2 dots
			wk_irState.sensors[2].rawX = data[12] | ((data[14] >> 4) & 0x03) << 8;
			wk_irState.sensors[2].rawY = data[13] | ((data[14] >> 6) & 0x03) << 8;
			wk_irState.sensors[2].size = data[14] & 0x0f;
			wk_irState.sensors[2].found = !(data[12] == 0xff && data[13] == 0xff && data[14] == 0xff);
			
			wk_irState.sensors[3].rawX = data[15] | ((data[17] >> 4) & 0x03) << 8;
			wk_irState.sensors[3].rawY = data[16] | ((data[17] >> 6) & 0x03) << 8;
			wk_irState.sensors[3].size = data[17] & 0x0f;
			wk_irState.sensors[3].found = !(data[15] == 0xff && data[16] == 0xff && data[17] == 0xff);
			
			break;
		default:
			WKLog(@"Unsupported IR Camera mode: %u bytes report", range.length);
			return;
	}
	
	for (NSUInteger idx = 0; idx < 4; idx++) {
		wk_irState.sensors[idx].x = wk_irState.sensors[idx].rawX / 1023.5;
		wk_irState.sensors[idx].y = wk_irState.sensors[idx].rawY / 767.5;
	}

	
	if(wk_irState.sensors[0].found && wk_irState.sensors[1].found) {
		wk_irState.rawX = (wk_irState.sensors[0].rawX + wk_irState.sensors[1].rawX) / 2;
		wk_irState.rawY = (wk_irState.sensors[0].rawY + wk_irState.sensors[1].rawY) / 2;
		
		wk_irState.x = (wk_irState.sensors[0].x + wk_irState.sensors[1].x) / 2.;
		wk_irState.y = (wk_irState.sensors[0].y + wk_irState.sensors[1].y) / 2.;
	} else {
		wk_irState.x = wk_irState.y = 0;
	}
}

- (void)parserWriteAck:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length == 2);
	[self didReceiveAck:data];
}

- (void)parseInterleavedLow:(const uint8_t *)data range:(NSRange)range {
	NSParameterAssert(range.length == 19);
	
	wk_interleaved[0] = data[range.location];
	
	/* extract Z bytes from button unused bits */
	wk_interleaved[2] = (data[0] & 0x60) >> 1;
	wk_interleaved[2] |= (data[1] & 0x60) << 1;
	
	/* copy low bytes of ir sensor */
	memcpy(wk_interleaved + 3, data + 1, 18);
}

- (void)parseInterleavedHigh:(const uint8_t *)data range:(NSRange)range {
	NSParameterAssert(range.length == 19);
	
	wk_interleaved[1] = data[range.location];
	
	/* extract Z bytes from button unused bits */
	wk_interleaved[2] |= (data[0] & 0x60) >> 5;
	wk_interleaved[2] |= (data[1] & 0x60) >> 3;
	
	/* copy high bytes of ir sensor */
	memcpy(wk_interleaved + 3 + 18, data + 1, 18);
	
	/* data completed */
	[self parseAccelerometer:wk_interleaved range:NSMakeRange(0, 3)];
	[self parseIRCamera:wk_interleaved + 3 range:NSMakeRange(0, 36)];
}

- (void)connection:(WKConnection *)aConnection didReceiveData:(uint8_t *)data length:(size_t)length {
	//NSLog(@"%@: %@", NSStringFromSelector(_cmd), [NSData dataWithBytesNoCopy:data length:length freeWhenDone:NO]);
	// printf("-\n");
	
	wk_wiiFlags.inTransaction = 1;
	NSUInteger type = data[0];
	
	length -= 1;
	data = data + 1;
	
	NSUInteger offset = 0;
	if (type != kWKInputReportLongExtension) {
		/* button state seems to be include in almost all reports */
		[self parseButtons:data length:length];
		offset = 2;
	}
	
	/* end of packet reached */
	if (length == 0) return;
	
	@try {
		switch (type) {
			case kWKInputReportStatus:
				[self parseStatus:data + offset length:length - offset];
				break;
			case kWKInputReportReadData:
				[self parseRead:data + offset length:length - offset];
				break;
			case kWKInputReportWriteData:
				[self parserWriteAck:data + offset length:length - offset];
				break;
				
				/* reports */
			case kWKInputReportDefault:
				// should never append
				break;
			case kWKInputReportAccelerometer:
				[self parseAccelerometer:data range:NSMakeRange(offset, 3)];
				break;
			case kWKInputReportShortExtension:
				[[self extension] parseStatus:data range:NSMakeRange(offset, 9)];
				break;
			case kWKInputReportAccelerometerIR:
        [self parseAccelerometer:data range:NSMakeRange(offset, 3)];
				[self parseIRCamera:data range:NSMakeRange(offset + 3, 12)];
				break;
			case kWKInputReportExtension:
				[[self extension] parseStatus:data range:NSMakeRange(offset, 19)];
				break;
			case kWKInputReportAccelerometerExtension:
				[self parseAccelerometer:data range:NSMakeRange(offset, 3)];
				[[self extension] parseStatus:data range:NSMakeRange(offset + 3, 16)];
				break;
			case kWKInputReportIRExtension:
				[self parseIRCamera:data range:NSMakeRange(offset, 10)];
				[[self extension] parseStatus:data range:NSMakeRange(offset + 10, 9)];
				break;
			case kWKInputReportAll:
				[self parseAccelerometer:data range:NSMakeRange(offset, 3)];
				[self parseIRCamera:data range:NSMakeRange(offset + 3, 10)];
				[[self extension] parseStatus:data range:NSMakeRange(offset + 13, 6)];
				break;
			case kWKInputReportLongExtension:
				[[self extension] parseStatus:data range:NSMakeRange(offset, 21)];
				break;
				/* interleaved */
			case kWKInputReportAllInterleavedLow:
				[self parseInterleavedLow:data range:NSMakeRange(offset, 19)];
				break;
			case kWKInputReportAllInterleavedHigh:
				[self parseInterleavedHigh:data range:NSMakeRange(offset, 19)];
				break;
			default:
				WKLog(@"Unsupported input report: %#lx", (long)type);
		}
	} @catch (NSException *exception) {
		WKLog(@"IO Exception: %@", exception);
	}
	
	wk_wiiFlags.inTransaction = 0;
	
	/* process pending request */
	if (wk_wiiFlags.status) {
		wk_wiiFlags.status = 0;
		[self refreshStatus];
	}
	if (wk_wiiFlags.reportMode) {
		wk_wiiFlags.reportMode = 0;
		[self refreshReportMode];
	}
}

@end
