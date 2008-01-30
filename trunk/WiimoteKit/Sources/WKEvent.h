//
//  WKEvent.h
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 17/01/08.
//  Copyright 2008 Ninsight. All rights reserved.
//

#import <WiimoteKit/WKTypes.h>

enum {
	kWKEventButtonUp = 1,
	kWKEventButtonDown,
	/* WiiRemote + nunchuk */
	kWKEventAccelerometer,
	
	/* WiiRemote Specific */
	kWKEventIRCamera,
	
	/* Nunchuk + Classic Controller */
	kWKEventJoystickMove,
	kWKEventAnalogButtonChange,
	
	kWKEventStatusChange, // wiimote status updated
};
typedef NSUInteger WKEventType;

/* Status event subtype */
enum {
	kWKStatusEventLights = 1,
	kWKStatusEventRumble,
	kWKStatusEventBattery,
	kWKStatusEventSpeaker,
	kWKStatusEventExtention,
};

/* button up/down subtype */
enum {
	kWKEventWiimoteButton = 1,
	kWKEventExtensionButton,
};
/* joystick subtype */
enum {
	kWKEventLeftJoystick = 1,
	kWKEventRightJoystick,
};
/* analog subtype */
enum {
	kWKEventAnalogLeftButton = 1,
	kWKEventAnalogRightButton,
};
/* accelerometer subtype */
enum {
	kWKEventWiimoteAccelerometer = 1,
	kWKEventExtensionAccelerometer,
};

typedef NSUInteger WKEventSubtype;

@class WiiRemote;
@interface WKEvent : NSObject {
@private
	WiiRemote *wk_remote;
	WKEventType wk_type;
	WKExtensionType wk_extension;
	union {
		struct {
			NSUInteger subtype;
			NSUInteger state;
		} button;
		struct {
			NSUInteger subtype;
			NSUInteger value;
		} status;
		struct {
			NSUInteger subtype;
			CGFloat x, y, z;
			CGFloat dx, dy, dz;
			NSUInteger rawx, rawy, rawz;
			NSUInteger rawdx, rawdy, rawdz;
		} acc;
		struct {
			NSUInteger subtype;
			CGFloat x;
			CGFloat dx;
			NSUInteger rawx;
			NSUInteger rawdx;
		} analog;
		struct {
			NSUInteger subtype;
			CGFloat x, y;
			CGFloat dx, dy;
			NSUInteger rawx, rawy;
			NSUInteger rawdx, rawdy;
		} joystick;
		struct {
			// TODO
		} ir;
	} wk_data;
}

+ (id)eventWithType:(WKEventType)aType wiimote:(WiiRemote *)aWiimote;
- (id)initWithType:(WKEventType)aType wiimote:(WiiRemote *)aWiimote;

- (WiiRemote *)wiimote;
/* if source is extension, this is the extension type */
- (WKExtensionType)extension;

- (WKEventType)type;
- (NSUInteger)subtype;

/* for status event */
- (NSUInteger)status;

- (NSUInteger)button; // device dependant

/* coord for accelerometer (x, y, z) and joystick (x, y only) */
- (CGFloat)x;
- (CGFloat)y;
- (CGFloat)z;

- (CGFloat)deltaX;
- (CGFloat)deltaY;
- (CGFloat)deltaZ;

- (NSInteger)absoluteX;
- (NSInteger)absoluteY;
- (NSInteger)absoluteZ;

- (NSInteger)absoluteDeltaX;
- (NSInteger)absoluteDeltaY;
- (NSInteger)absoluteDeltaZ;

@end

@interface WKEvent (WKEventPrivate)

- (void)setSubtype:(WKEventSubtype)aSubtype;

- (void)setStatus:(NSUInteger)aStatus;
- (void)setButton:(NSUInteger)aButton;

- (void)setX:(CGFloat)value;
- (void)setY:(CGFloat)value;
- (void)setZ:(CGFloat)value;

- (void)setDeltaX:(CGFloat)delta;
- (void)setDeltaY:(CGFloat)delta;
- (void)setDeltaZ:(CGFloat)delta;

- (void)setAbsoluteX:(NSUInteger)value;
- (void)setAbsoluteY:(NSUInteger)value;
- (void)setAbsoluteZ:(NSUInteger)value;

- (void)setAbsoluteDeltaX:(NSUInteger)value;
- (void)setAbsoluteDeltaY:(NSUInteger)value;
- (void)setAbsoluteDeltaZ:(NSUInteger)value;

@end


