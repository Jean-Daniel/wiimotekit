//
//  WKEvent.m
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 13/01/08.
//  Copyright 2008 Shadow Lab. All rights reserved.
//

#import <WiimoteKit/WKEvent.h>
#import <WiimoteKit/WiiRemote.h>
#import <WiimoteKit/WKExtension.h>

@implementation WKEvent

+ (id)eventWithType:(WKEventType)aType wiimote:(WiiRemote *)aWiimote {
	return [[[self alloc] initWithType:aType wiimote:aWiimote] autorelease];
}

- (id)initWithType:(WKEventType)aType wiimote:(WiiRemote *)aWiimote {
	NSParameterAssert(aType);
	NSParameterAssert(aWiimote);
	
	if (self = [super init]) {
		wk_type = aType;
		wk_remote = [aWiimote retain];
		wk_extension = [[aWiimote extension] type];
	}
	return self;
}

- (void)dealloc {
	[wk_remote release];
	[super dealloc];
}

- (NSString *)description {
	NSString *type = nil;
	switch (wk_type) {
		case kWKEventButtonUp:
			type = @"button down";
			break;
		case kWKEventButtonDown:
			type = @"button up";
			break;
		case kWKEventIRCamera:
			type = @"ir camera";
			break;
		case kWKEventAccelerometer:
			type = @"accelerometer";
			break;
		case kWKEventJoystickMove:
			type = @"joystick";
			break;
		case kWKEventAnalogButtonChange:
			type = @"analog button";
			break;
		case kWKEventStatusChange:
			type = @"status";
			break;
	}
	return [NSString stringWithFormat:@"<%@ %p> { type: %@ }", 
					[self class], self, type];
}

#pragma mark -
- (BOOL)__supportSubtype {
	switch (wk_type) {
		case kWKEventButtonUp:
		case kWKEventButtonDown:
		case kWKEventStatusChange: 
		case kWKEventAccelerometer:
			return YES;
		case kWKEventJoystickMove:
		case kWKEventAnalogButtonChange:
			return wk_extension == kWKExtensionClassicController;
	}
	return NO;
}

- (WiiRemote *)wiimote {
	return wk_remote;
}
- (WKExtensionType)extension {
	return wk_extension;
}

- (WKEventType)type {
	return wk_type;
}

- (NSUInteger)subtype {
	NSParameterAssert([self __supportSubtype]);
	switch (wk_type) {
		case kWKEventButtonUp:
		case kWKEventButtonDown:
			return wk_data.button.subtype;
		case kWKEventStatusChange:
			return wk_data.status.subtype;
		case kWKEventAccelerometer:
			return wk_data.acc.subtype;
		case kWKEventJoystickMove:
			return wk_data.joystick.subtype;
		case kWKEventAnalogButtonChange:
			return wk_data.analog.subtype;
	}
	return 0;
}
- (void)setSubtype:(WKEventSubtype)aSubtype {
	NSParameterAssert([self __supportSubtype]);
	switch (wk_type) {
		case kWKEventButtonUp:
		case kWKEventButtonDown:
			wk_data.button.subtype = aSubtype;
			break;
		case kWKEventStatusChange:
			wk_data.status.subtype = aSubtype;
			break;
		case kWKEventAccelerometer:
			wk_data.acc.subtype = aSubtype;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.subtype = aSubtype;
			break;
		case kWKEventAnalogButtonChange:
			wk_data.analog.subtype = aSubtype;
			break;
	}
}

- (NSUInteger)status {
	NSParameterAssert(wk_type == kWKEventStatusChange);
	return wk_data.status.value;
}
- (void)setStatus:(NSUInteger)aStatus {
	NSParameterAssert(wk_type == kWKEventStatusChange);
	wk_data.status.value = aStatus;
}

- (NSUInteger)button {
	NSParameterAssert(wk_type == kWKEventButtonDown || wk_type == kWKEventButtonUp);
	return wk_data.button.state;
}
- (void)setButton:(NSUInteger)button {
	NSParameterAssert(wk_type == kWKEventButtonDown || wk_type == kWKEventButtonUp);
	wk_data.button.state = button;
}

#pragma mark -
#pragma mark Calibrated
- (CGFloat)x {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.x;
		case kWKEventJoystickMove:
			return wk_data.joystick.x;
		case kWKEventAnalogButtonChange:
			return wk_data.analog.x;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support X" userInfo:nil];
	}
}
- (void)setX:(CGFloat)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.x = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.x = value;
			break;
		case kWKEventAnalogButtonChange:
			wk_data.analog.x = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support X" userInfo:nil];
	}
}

- (CGFloat)y {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.y;
		case kWKEventJoystickMove:
			return wk_data.joystick.y;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Y" userInfo:nil];
	}
}
- (void)setY:(CGFloat)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.y = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.y = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Y" userInfo:nil];
	}
}

- (CGFloat)z {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.z;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Z" userInfo:nil];
	}
}
- (void)setZ:(CGFloat)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.z = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Z" userInfo:nil];
	}
}

- (CGFloat)deltaX {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.dx;
		case kWKEventJoystickMove:
			return wk_data.joystick.dx;
		case kWKEventAnalogButtonChange:
			return wk_data.analog.dx;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta X" userInfo:nil];
	}	
}
- (void)setDeltaX:(CGFloat)delta {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.dx = delta;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.dx = delta;
			break;
		case kWKEventAnalogButtonChange:
			wk_data.analog.dx = delta;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta X" userInfo:nil];
	}
}

- (CGFloat)deltaY {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.dy;
		case kWKEventJoystickMove:
			return wk_data.joystick.dy;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Y" userInfo:nil];
	}	
}
- (void)setDeltaY:(CGFloat)delta {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.dy = delta;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.dy = delta;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Y" userInfo:nil];
	}
}

- (CGFloat)deltaZ {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.dz;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Z" userInfo:nil];
	}	
}
- (void)setDeltaZ:(CGFloat)delta {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.dz = delta;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Z" userInfo:nil];
	}
}

#pragma mark Absolute
- (NSInteger)absoluteX {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawx;
		case kWKEventJoystickMove:
			return wk_data.joystick.rawx;
		case kWKEventAnalogButtonChange:
			return wk_data.analog.rawx;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support X" userInfo:nil];
	}
}
- (void)setAbsoluteX:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawx = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.rawx = value;
			break;
		case kWKEventAnalogButtonChange:
			wk_data.analog.rawx = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support X" userInfo:nil];
	}
}

- (NSInteger)absoluteY {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawy;
		case kWKEventJoystickMove:
			return wk_data.joystick.rawy;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Y" userInfo:nil];
	}	
}
- (void)setAbsoluteY:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawy = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.rawy = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Y" userInfo:nil];
	}
}

- (NSInteger)absoluteZ {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawz;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Z" userInfo:nil];
	}
}
- (void)setAbsoluteZ:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawz = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support Z" userInfo:nil];
	}
}

- (NSInteger)absoluteDeltaX {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawdx;
		case kWKEventJoystickMove:
			return wk_data.joystick.rawdx;
		case kWKEventAnalogButtonChange:
			return wk_data.analog.rawdx;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta X" userInfo:nil];
	}
}
- (void)setAbsoluteDeltaX:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawdx = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.rawdx = value;
			break;
		case kWKEventAnalogButtonChange:
			wk_data.analog.rawdx = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta X" userInfo:nil];
	}
}

- (NSInteger)absoluteDeltaY {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawdy;
		case kWKEventJoystickMove:
			return wk_data.joystick.rawdy;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Y" userInfo:nil];
	}	
}
- (void)setAbsoluteDeltaY:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawdy = value;
			break;
		case kWKEventJoystickMove:
			wk_data.joystick.rawdy = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Y" userInfo:nil];
	}
}

- (NSInteger)absoluteDeltaZ {
	switch (wk_type) {
		case kWKEventAccelerometer:
			return wk_data.acc.rawdz;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Z" userInfo:nil];
	}
}
- (void)setAbsoluteDeltaZ:(NSUInteger)value {
	switch (wk_type) {
		case kWKEventAccelerometer:
			wk_data.acc.rawdz = value;
			break;
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Event does not support delta Z" userInfo:nil];
	}
}

@end
