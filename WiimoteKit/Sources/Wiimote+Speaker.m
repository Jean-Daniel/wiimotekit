//
//  Wiimote+Speaker.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 18/01/08.
//  Copyright 2008 Ninsight. All rights reserved.
//

#import <WiimoteKit/WiiRemote.h>

#import "WiiRemoteInternal.h"

@implementation WiiRemote (WiiRemoteSpeaker)

- (BOOL)isSpeakerEnabled {
	return wk_wiiFlags.speaker;
}

- (void)__stopSpeaker {
	wk_wiiFlags.speakerInit = 0;
	wk_wiiFlags.speakerAbort = 0;
	[self sendCommand:(const uint8_t[]){ WKOutputReportSpeakerStatus, 0x00 } length:2];
	[self refreshStatus];
}

- (void)setSpeakerEnabled:(BOOL)flag {
	flag = flag ? 1 : 0; // canoniz
	if (wk_wiiFlags.speaker != flag) {
		if (!flag) {
			if (wk_wiiFlags.speakerInit) {
				wk_wiiFlags.speakerAbort = 1;
			} else {
				[self __stopSpeaker];
			}
		} else {
			if (!wk_wiiFlags.speakerInit) {
				wk_wiiFlags.speakerInit = 1;
				/* start speaker */
				[self sendCommand:(const uint8_t[]){ WKOutputReportSpeakerStatus, 0x04 } length:2];
				[self sendCommand:(const uint8_t[]){ WKOutputReportSpeakerMute, 0x04 } length:2];
				// TODO 
				//				[self writeData:(const uint8_t[]){ 0x01 } length:1 atAddress:IR_REGISTER_STATUS 
				//									space:kWKMemorySpaceIRCamera next:@selector(didStartSpeaker:)];
				/* following operation are done in the data send callback */
			}
		}
	}
}

- (BOOL)isSpeakerMuted {
	return wk_wiiFlags.muted;
}
- (void)setSpeakerMuted:(BOOL)flag {
	IOReturn err = kIOReturnSuccess;
	flag = flag ? 1 : 0; // canoniz
	if (wk_wiiFlags.muted != flag) {
		err = [self sendCommand:(const uint8_t[]){ WKOutputReportSpeakerMute, flag ? 0x04 : 0 } length:2];
//		if (kIOReturnSuccess == err)
//			err = [self refreshStatus]; // will send a speaker state change notification
	}
	WKPrintIOReturn(err, "setSpeakerMute");	
}

- (void)setSpeakerDataSource:(id<WiiRemoteSpakerDataSource>)source {
	
}

- (NSUInteger)speakerRate {
	return 0;
}

@end
