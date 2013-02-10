//
//  AppDelegate.h
//  bluetest
//
//  Created by Ian on 1/7/13.
//  Copyright (c) 2013 Ian Atha. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/IOBluetooth.h>

@interface MainDelegate : NSObject <NSApplicationDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>
{
    CBCentralManager *manager;
    NSMutableSet *discoveredPeripherals;
    NSArray *otpServices;
    NSArray *otpCharacteristics;
    NSStatusItem* trayItem;

}

@property (retain) CBPeripheral *lastPeripheral;
@property (retain) NSString *lastData;
@property BOOL typeItOut;
@property IBOutlet NSMenu *statusMenu;
//@property (assign) IBOutlet NSWindow *window;
@property (retain) IBOutlet NSMenuItem *getOTPButton;
//@property (weak) IBOutlet NSTextField *OTPValue;
@property (retain) IBOutlet NSMenuItem *connectToiPhoneMenu;

- (IBAction)addIphone:(id)sender;
- (IBAction) quitClicked:(id)sender;
- (IBAction)getOTP2Clicked:(id)sender;

@end
