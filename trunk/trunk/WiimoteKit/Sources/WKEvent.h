//
//  WKEvent.h
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 17/01/08.
//  Copyright 2008 Ninsight. All rights reserved.
//

#import <WiimoteKit/WKTypes.h>

enum {
	kWKEventButtonUp,
	kWKEventButtonDown,
	/* WiiRemote + nunchuk */
	kWKEventAccelerometer,
	/* WiiRemote Specific */
	kWKEventIRCamera,
	/* Nunchuk + Classic Controller */
	kWKEventJoystickMove,
	
	kWKEventStatusChange, // wiimote status updated
};

enum {
	kWKEventSourceWiiRemote,
	kWKEventSourceExtension,
};
typedef NSUInteger WKEventSource;

/* Status event subtype */
enum {
	kWKStatusEventLights,
	kWKStatusEventRumble,
	kWKStatusEventBattery,
	kWKStatusEventSpeaker,
	kWKStatusEventExtention,
};
typedef NSUInteger WKEventSubType;

@class WiiRemote;
@interface WKEvent : NSObject {
@private
	WiiRemote *wk_remote;
	
	CGFloat wk_dx, wk_dy, wk_dz;
}

- (WiiRemote *)wiimote;

- (NSUInteger)button; // device dependant

/* is it a wiimote event, or an extension event, ... */
- (WKEventSource)source;
/* if source is extension, this is the extension type */
- (WKExtensionType)extension;

/* coord for accelerometer (x, y, z) and joystick (x, y only) */
- (NSInteger)absoluteX;
- (NSInteger)absoluteY;
- (NSInteger)absoluteZ;

- (CGFloat)calibratedX;
- (CGFloat)calibratedY;
- (CGFloat)calibratedZ;

- (CGFloat)deltaX;
- (CGFloat)deltaY;
- (CGFloat)deltaZ;

@end
