//
//  WiiRemote.h
//  WiimoteKit
//
//  Created by Jean-Daniel Dupas on 12/01/08.
//  Copyright 2008 Shadow Lab.. All rights reserved.
//

#import <WiimoteKit/WKTypes.h>

enum {
	kWKWiiRemoteButtonTwo    = 1 << 0,
	kWKWiiRemoteButtonOne    = 1 << 1,
	kWKWiiRemoteButtonB      = 1 << 2,
	kWKWiiRemoteButtonA      = 1 << 3,
	kWKWiiRemoteButtonMinus  = 1 << 4,
	kWKWiiRemoteButtonHome   = 1 << 7,
	
	kWKWiiRemoteButtonLeft   = 1 << 8,
	kWKWiiRemoteButtonRight  = 1 << 9,
	kWKWiiRemoteButtonDown   = 1 << 10,
	kWKWiiRemoteButtonUp     = 1 << 11,
	kWKWiiRemoteButtonPlus   = 1 << 12,
	
	kWKWiiRemoteButtonsMask   = 0x1f9f,
};
/*!
 @typedef 
 @abstract Digital button on the Wiimote
 */
typedef NSUInteger WKWiiRemoteButtonsState;

#pragma mark States
enum {
	kWKLEDOne   = 1 << 0,
	kWKLEDTwo   = 1 << 1,
	kWKLEDThree = 1 << 2,
	kWKLEDFour  = 1 << 3,
};
typedef NSUInteger WKLEDState;

/*!
 @enum
 @abstract The mode of data reported for the IR sensor
 @constant kWKIRModeOff IR sensor off
 @constant kWKIRModeBasic Basic mode
 @constant kWKIRModeExtended kWKIRModeExtended
 @constant kWKIRModeFull kWKIRModeFull (unsupported)
 */
enum {
	kWKIRModeOff      = 0x00,
	kWKIRModeBasic    = 0x01, // 10 bytes
	kWKIRModeExtended = 0x03, // 12 bytes
	kWKIRModeFull     = 0x05, // 16 bytes * 2 (format unknown)
};
typedef NSUInteger WKIRMode;

/*!
 @struct
 @abstract Current state of the IR camera
 @field mode Current mode of IR sensor data
 @field rawX Raw midpoint of IR sensors. Values range between 0 - 1023.
 @field rawY Raw midpoint of IR sensors. Values range between 0 - 767.
 @field x Normalized midpoint of IR sensors. Values range between 0.0 - 1.0
 @field y Normalized midpoint of IR sensors. Values range between 0.0 - 1.0
 @field sensors Individual sensors values.
 */
typedef struct _WKIRState {
	WKIRMode mode;
	CGFloat x, y;
	uint16_t rawX, rawY;
	
	struct {
		BOOL found; // IR sensor seen
		uint8_t size; // Size of IR Sensor.  Values range from 0 - 15
		uint16_t rawX, rawY; // X Values range between 0 - 1023, Y Values range between 0 - 767.
		CGFloat x, y; // Normalized value of X/Y-axis on individual sensor.  Values range between 0.0 - 1.0
	} sensors[4];
} WKIRState;

@class IOBluetoothDevice;
@class WKExtension, WKConnection;
@interface WiiRemote : NSObject {
@private
	// Current state of IR sensors
	WKIRState wk_irState;
	// Current state of accelerometers
	WKAccelerationState wk_accState;
	// Current calibration information
	WKAccelerationCalibration wk_accCalib;

	WKExtension *wk_extension; // extension
	
	struct _wk_wiiFlags {
		unsigned int leds:5; // Current state of LEDs
		unsigned int rumble:1; // Current state of the force feedback
		unsigned int speaker:1; // speaker is enabled ?
		unsigned int battery:8; // Current battery level
		
		unsigned int remoteButtons:16; /* wii remote buttons state */
		
		/* tracking mode */
		unsigned int continuous:1; // should track continously
		unsigned int accelerometer:1; // should listen accelerometer
		
		/* transaction flags */
		unsigned int status:1;
		unsigned int reportMode:1;
		unsigned int inTransaction:1;
		
		/* download */
		unsigned int expected:16;
		/* race condition */
		unsigned int initializing:1;
	} wk_wiiFlags;
	
	NSMutableData *wk_buffer; /* download buffer */
	uint8_t wk_interleaved[39]; /* interleaved buffer */
	WKConnection *wk_connection; /* bluetooth HID connection */
	
	/* read/write request serialization */
	CFMutableArrayRef wk_rRequests;
	CFMutableArrayRef wk_wRequests;
}

#pragma mark Device
- (id)initWithDevice:(IOBluetoothDevice *)aDevice;

- (BOOL)isConnected;

- (NSString *)address;
- (WKConnection *)connection;

#pragma mark Wiimote Status
- (BOOL)isContinuous;
- (void)setContinuous:(BOOL)value;

- (BOOL)acceptsIRCameraEvents;
- (void)setAcceptsIRCameraEvents:(BOOL)flag;

- (BOOL)acceptsAccelerometerEvents;
- (void)setAcceptsAccelerometerEvents:(BOOL)flag;

@end

@interface WiiRemote (WiiRemoteStatus)

- (WKLEDState)leds;
- (void)setLeds:(WKLEDState)leds;

- (BOOL)isRumbleEnabled;
- (void)setRumbleEnabled:(BOOL)rumble;

/* read only */
/*!
 @method
 @result Returns a number from 0.0 through 1.0 (1.0 mean battery full)
 */
- (CGFloat)battery;
- (WKExtension *)extension;

@end

@protocol WiiRemoteSpakerDataSource
/* this delaration is just a remainder */
- (NSUInteger)getPCMData:(uint8_t *)buffer length:(size_t)length;

@end

@interface WiiRemote (WiiRemoteSpeaker)

- (BOOL)isSpeakerEnabled;
- (void)setSpeakerEnabled:(BOOL)flag;

- (BOOL)isSpeakerMuted;
- (void)setSpeakerMuted:(BOOL)flag;

- (void)setSpeakerDataSource:(id<WiiRemoteSpakerDataSource>)source;

@end