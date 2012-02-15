//
//  SensorLogger_ListenerAppDelegate.h
//  SensorLogger Listener
//
//  Created by Scott Gerring on 9/07/10.
//  Copyright 2010 AmongstBits. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

@interface SensorLogger_ListenerAppDelegate : NSObject <NSApplicationDelegate> 
	{
		/**
		UI elements
		**/
		NSWindow *window;
		NSTextField* portField;
		NSTextView* outputField;
		
		/**
		To format our output dates
		**/
		NSDateFormatter* dateFormatter;
		
		/**
		Start and stop buttons. We need to enable
		and disable them.
		**/
		NSButton* startButton;
		NSButton* stopButton;
		
		/**
		Our socket for listening to the client
		**/
		AsyncUdpSocket* socket;
		
		/**
		Log types, as received off the wire.
		**/
		enum 
		{
			GPS = 1,
			Compass = 2,
			Accelerometer = 3,
			Gyroscope = 4
		} LogRecordType;
	}
	
	-(void)initialiseSocket;
	
	-(IBAction)startClicked:(id)sender;
	-(IBAction)stopClicked:(id)sender;
	
	@property (nonatomic, retain) IBOutlet NSButton* startButton;
	@property (nonatomic, retain) IBOutlet NSButton* stopButton;
	@property (nonatomic, retain) IBOutlet NSTextField* portField;
	@property (nonatomic, retain) IBOutlet NSTextView* outputField;
	@property (assign) IBOutlet NSWindow *window;

@end
