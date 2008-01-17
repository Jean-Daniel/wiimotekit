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

// The report format in which the Wiimote should return data
enum WKInputReport {
	// Status report
	kWKInputReportStatus    = 0x20, // 6 bytes
	// Read data from memory location
	kWKInputReportReadData  = 0x21, // 21 bytes
	// Write status to memory location
	kWKInputReportWriteData = 0x22, // 4 bytes
	
	kWKInputReportDefault                = 0x30, // 2 bytes. buttons only
	kWKInputReportAccelerometer          = 0x31, // 3 bytes
	kWKInputReportShortExtension         = 0x32, // 9 bytes
	kWKInputReportAccelerometerIR        = 0x33, // 3 - 12 bytes
	kWKInputReportExtension              = 0x34, // 19 bytes
	kWKInputReportAccelerometerExtension = 0x35, // 3 - 16 bytes
	kWKInputReportIRExtension            = 0x36, // 10 - 9 bytes
	kWKInputReportAll                    = 0x37, // 3 - 10 - 6 bytes
	kWKInputReportLongExtension          = 0x3d, // 21 bytes. WARNING, this report does not include buttons.
	/* interleaved */
	kWKInputReportAllInterleavedLow      = 0x3e, // 1 - 18 bytes
	kWKInputReportAllInterleavedHigh     = 0x3f, // 1 - 18 bytes
};

#define kWiiIRPixelsWidth 1024.0
#define kWiiIRPixelsHeight 768.0

@interface WiiRemote (WKConnectionParser)
- (void)parserWriteAck:(const uint8_t *)data length:(size_t)length;
- (void)parseButtons:(const uint8_t *)data length:(size_t)length;
- (void)parseStatus:(const uint8_t *)data length:(size_t)length;
- (void)parseRead:(const uint8_t *)data length:(size_t)length;

/* report */
- (void)parseAccelerometer:(const uint8_t *)data range:(NSRange)range;
- (void)parseIRCamera:(const uint8_t *)data range:(NSRange)range;

@end

@implementation WiiRemote (WKConnectionParser)

- (void)parseButtons:(const uint8_t *)data length:(size_t)length {
	NSParameterAssert(length >= 2);
	WKWiiRemoteButtonsState state = OSReadBigInt16(data, 0) & kWKWiiRemoteButtonsMask;
	if (state != wk_wiiFlags.remoteButtons) {
		wk_wiiFlags.remoteButtons = state;
		// TODO: compute delta
		WKLog(@"TODO: Notify buttons changed: %x", wk_wiiFlags.remoteButtons);
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
		WKLog(@"TODO: Speaker status did change");
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
		WKLog(@"TODO: led status did change");
	}
	
	/* check battery level */
	uint8_t battery = data[3];
	if (battery != wk_wiiFlags.battery) {
		wk_wiiFlags.battery = battery;
		WKLog(@"TODO: Battery did change: %.0f%%", wk_wiiFlags.battery * 100. / 0xc0);
	}
}

- (void)parseCalibration:(const uint8_t *)memory length:(size_t)length {
	wk_accCalib.x0 = memory[0] << 1;
	wk_accCalib.y0 = memory[1] << 1;
	wk_accCalib.z0 = memory[2] << 1;
	wk_accCalib.xG = memory[4] << 1;
	wk_accCalib.yG = memory[5] << 1;
	wk_accCalib.zG = memory[6] << 1;
}

- (void)didReceiveData:(const uint8_t *)data length:(size_t)length {
	WKReadRequest request;
	wk_requests = __WKReadRequestPop(wk_requests, &request);
	switch (request) {
		case kWKExtensionTypeRequest: { // extension type
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
					break;
				default:
					WKLog(@"TODO: report unsupported extension");
					break;
			}
			[self setExtensionType:type];
			wk_wiiFlags.initializing = 0;
		}
			break;
		case kWKWiiRemoteCalibrationRequest:
			// read wiimote calibration
			[self parseCalibration:data length:length];
			break;
		case kWKExtensionCalibrationRequest:
			// extension request
			[[self extension] parseCalibration:data length:length];
			break;
		case kWKMiiDataRequest:
			// mii
			break;
		default:
			WKLog(@"receive data but does not waiting something");
	}
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
	
	uint8_t rawx, rawy, rawz;
#if defined(NINE_BITS_ACCELEROMETER)
	// cam: added 9th bit of resolution to the wii acceleration
	// see http://www.wiili.org/index.php/Talk:Wiimote#Remaining_button_state_bits
	uint16_t adjust = OSReadBigInt16(data, 0);
	
	rawx = (data[range.location] << 1) | (adjust & 0x0040) >> 6;
	rawy = (data[range.location + 1] << 1) | (adjust & 0x2000) >> 13;
	rawz = (data[range.location + 2] << 1) | (adjust & 0x4000) >> 14;
#else
	rawx = data[range.location];
	rawy = data[range.location + 1];
	rawz = data[range.location + 2];	
#endif
	
	if (rawx != wk_accState.rawX || rawx != wk_accState.rawX || rawx != wk_accState.rawX) {
		wk_accState.rawX = rawx;
		wk_accState.rawY = rawy;
		wk_accState.rawZ = rawz;
		
		/* compute calibrated values */
		if (wk_accCalib.x0)
			wk_accState.x = (CGFloat)(wk_accState.rawX - wk_accCalib.x0) / (wk_accCalib.xG - wk_accCalib.x0);
		if (wk_accCalib.y0)
			wk_accState.y = (CGFloat)(wk_accState.rawY - wk_accCalib.y0) / (wk_accCalib.yG - wk_accCalib.y0);
		if (wk_accCalib.z0)
			wk_accState.z = (CGFloat)(wk_accState.rawZ - wk_accCalib.z0) / (wk_accCalib.zG - wk_accCalib.z0);
		
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
		
		WKLog(@"TODO: Wiimote position change");
	}
}

- (void)parseIRCamera:(const uint8_t *)data range:(NSRange)range {
	NSLog(@"%@%lu", NSStringFromSelector(_cmd), (long)range.length);
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
	// NSLog(@"%@: %@", NSStringFromSelector(_cmd), [NSData dataWithBytesNoCopy:data length:length freeWhenDone:NO]);
	printf("-\n");
	
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
		[self updateReportMode];
	}
}

@end
