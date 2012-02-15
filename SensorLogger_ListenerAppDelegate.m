//
//  SensorLogger_ListenerAppDelegate.m
//  SensorLogger Listener
//
//  Created by Scott Gerring on 9/07/10.
//  Copyright 2010 AmongstBits. All rights reserved.
//

#import "SensorLogger_ListenerAppDelegate.h"

@implementation SensorLogger_ListenerAppDelegate
	
	
	#pragma mark -
	#pragma mark Accessors
	
	
	@synthesize window;
	@synthesize portField;
	@synthesize outputField;
	@synthesize startButton;
	@synthesize stopButton;
	
	
	#pragma mark -
	#pragma mark Object Lifecycle
	
	
	/**
	Initialization bits.
	**/
	- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
	{
		// Create the socket
		[self initialiseSocket];
		
		// Create a date formatter for nice output
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"MM-dd-YYYY hh:mm:ss.SSSS"];
	}
	
	/**
	Destructor
	**/
	-(void)dealloc
	{
		[dateFormatter release];
		[socket release];
		[super dealloc];
	}
	
	
	#pragma mark -
	#pragma mark Utility
		
	
	/**
	Creates the socket, releasing the previous socket if
	present.
	**/
	
	-(void)initialiseSocket
	{
		[socket release];
		socket = [[AsyncUdpSocket alloc] initIPv4];
		[socket setDelegate:self];
	}
	
	/**
	Writes a log message to the window.
	**/
	-(void)writeLog:(NSString*)logStr
	{
		NSAttributedString* att = [[[NSAttributedString alloc] initWithString:[logStr stringByAppendingString:@"\n"]] autorelease];
		NSTextStorage *storage = [outputField textStorage];
		
		// Add the text
		[storage beginEditing];
		[storage appendAttributedString:att];
		[storage endEditing];
		
		// Scroll to the bottom
		[outputField scrollRangeToVisible:NSMakeRange([storage length],0)];

	}
		
	-(NSString*)getSensorName:(unsigned int)sensorNumber
	{
		NSString* name = @"Unknown";
		switch (sensorNumber)
		{
			case GPS:
				name = @"GPS";
				break;
			case Compass:
				name = @"Compass";
				break;
			case Accelerometer:
				name = @"Accelerometer";
				break;
		}
		return name;		
	}
	
	
	#pragma mark -
	#pragma mark Sensor Handlers
	
	
	/**
	This gets called for all compass data we receive.
	**/
	-(void)handleCompassMagneticHeading:(float)magneticHeading trueHeading:(float)trueHeading date:(NSDate*)date
	{
		NSString* dateStr = [dateFormatter stringFromDate:date];
		[self writeLog:[NSString stringWithFormat:@"%@ : Compass Magnetic Heading %3.5f True Heading %3.5f", dateStr, magneticHeading, trueHeading]];	
	}
	
	/**
	This gets called for all position data we receive.
	**/
	-(void)handleGPSLatitude:(double)latitude longitude:(double)longitude altitude:(double)altitude horizAccuracy:(double)hAcc vertAccuracy:(double)vAcc date:(NSDate*)date
	{
		NSString* dateStr = [dateFormatter stringFromDate:date];
		[self writeLog:[NSString stringWithFormat:@"%@ : GPS Latitude %3.5f Longitude %3.5f Altitude: %3.1f", dateStr, latitude, longitude, altitude]];
	}
	
	/**
	This gets called for all acceleration data we receive.
	**/
	-(void)handleAccelerationX:(double)x Y:(double)y Z:(double)z date:(NSDate*)date
	{
		NSString* dateStr = [dateFormatter stringFromDate:date];
		[self writeLog:[NSString stringWithFormat:@"%@ : Acceleration X %3.5f Y %3.5f Z %3.5f", dateStr, x, y, z]];	
	}
		
	/**
	This gets called for all gyroscope data we receive.
	**/
	-(void)handleGyroscopeX:(double)x Y:(double)y Z:(double)z date:(NSDate*)date
	{
		NSString* dateStr = [dateFormatter stringFromDate:date];
		[self writeLog:[NSString stringWithFormat:@"%@ : Gyroscope X %3.5f Y %3.5f Z %3.5f", dateStr, x, y, z]];	
	}
	
	
	#pragma mark Callbacks
	#pragma mark -
	
	/**
	Binds to the socket specified in the text field, and listens for
	broadcast events.
	**/
	-(IBAction)startClicked:(id)sender
	{
		// Get the port number
		unsigned int port = [[portField stringValue] intValue];
		NSError* error;
		if (![socket bindToPort:port error:&error])
		{
			[self writeLog:@"Failed binding to port!"];
		}
		else 
		{
			// Switch the buttons
			[startButton setEnabled:NO];
			[stopButton setEnabled:YES];
			
			// Schedule a receive
			[socket receiveWithTimeout:-1 tag:1];
			
			// Log our success
			[self writeLog:[NSString stringWithFormat:@"Bound to port %d",port]];
		}

	}
	
	/**
	Unbinds the socket from the port.
	**/
	-(IBAction)stopClicked:(id)sender
	{
		// Recreate the socket. It seems like there should be a way to 'unbind' it, but
		// a cruise through the AsyncUdpSocket API doesn't readily reveal one.
		[self initialiseSocket];
						
		// Switch buttons back
		[startButton setEnabled:YES];
		[stopButton setEnabled:NO];
	}
	
	/**
	Handles received data, dispatching to the appropriate sensor data handle.
	**/
	- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port;
	{
		// Records are sent as an ASCII encoded, comma-delimeted string, to make it super easy to decode.
		NSString* str = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		if (str && [str length] > 0)
		{
			NSArray* fields = [str componentsSeparatedByString:@","];
			if ([fields count] >= 3)
			{
				// Get the date - time is sent to us in ticks, so we have to /1000 to get in seconds for NSDate.
				unsigned long long ticks = strtoull([[fields objectAtIndex:0] UTF8String], NULL, 0);
				NSTimeInterval interval = (long double)ticks / 1000.0;
				NSDate* date = [NSDate dateWithTimeIntervalSince1970:interval];
				NSString* dateStr = [dateFormatter stringFromDate:date];
				
				// Get the sensor
				unsigned int sensorId = [[fields objectAtIndex:1] intValue];
				NSString* sensor = [self getSensorName:sensorId];
				
				// Store the data fields and send them off to the appropriate handler
				NSRange range;
				range.location = 2;
				range.length = [fields count] - 2;
				NSArray* dataFields = [fields subarrayWithRange:range];
				
				switch (sensorId)
				{
					case GPS:
					{
						if ([dataFields count] >= 4)
						{
							[self handleGPSLatitude:[[dataFields objectAtIndex:0] doubleValue] 
										  longitude:[[dataFields objectAtIndex:1] doubleValue] 
										  altitude:[[dataFields objectAtIndex:2] doubleValue]
										  horizAccuracy:[[dataFields objectAtIndex:3] doubleValue]
										  vertAccuracy:[[dataFields objectAtIndex:4] doubleValue]
										  date:date];
						}
						break;
					}
					case Compass:
					{
						if ([dataFields count] >= 2)
						{
							[self handleCompassMagneticHeading:[[dataFields objectAtIndex:0] doubleValue] 
												   trueHeading:[[dataFields objectAtIndex:1] doubleValue]
												   date:date];						
						}
						break;
					}
					case Accelerometer:
					{
						if ([dataFields count] >= 3)
						{
							[self handleAccelerationX:[[dataFields objectAtIndex:0] doubleValue] 
													Y:[[dataFields objectAtIndex:1] doubleValue] 
													Z:[[dataFields objectAtIndex:2] doubleValue]
													date:date];
						}
						break;
					}
					case Gyroscope:
					{
						if ([dataFields count] >= 3)
						{
							[self handleGyroscopeX:[[dataFields objectAtIndex:0] doubleValue] 
												 Y:[[dataFields objectAtIndex:1] doubleValue] 
												 Z:[[dataFields objectAtIndex:2] doubleValue]
												 date:date];
						}
						break;
					}
					default:
					{
						// No sensor match - just write it out raw.
						NSString* data = [dataFields componentsJoinedByString:@","];
						[self writeLog:[NSString stringWithFormat:@"[%@] %@ : %@", dateStr, sensor, data]];
					}
				}
			}
		}

		return NO;
	}

@end
