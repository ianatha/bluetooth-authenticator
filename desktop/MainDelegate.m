#import "MainDelegate.h"
#import "OTPOverBluetooth.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h>

@implementation MainDelegate

- (id)init {
    self = [super init];
    if (self) {
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        discoveredPeripherals = [[NSMutableSet alloc] init];
        otpServices = @[ [CBUUID UUIDWithString:OTPOverBluetoothService] ];
        otpCharacteristics = @[
             [CBUUID UUIDWithString:OTPOverBluetoothAvailableAccounts]
        ];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	trayItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    [self.statusMenu setAutoenablesItems:NO];
	[trayItem setMenu:self.statusMenu];
	[trayItem setHighlightMode:YES];
	[trayItem setTitle:@"Blauth"];
    [self addIphone:nil];
}

- (void)awakeFromNib {
    [self.connectToiPhoneMenu setEnabled:NO];
    [self.getOTPButton setEnabled:NO];
}

- (IBAction)addIphone:(id)sender {
    self.typeItOut = NO;
   
    if ([discoveredPeripherals count] == 0) {
        [manager scanForPeripheralsWithServices:otpServices options:@{ CBCentralManagerScanOptionAllowDuplicatesKey: @YES }];
    } else {
        for (CBPeripheral* peripheral in discoveredPeripherals) {
            NSLog(@"discovering services on %@", peripheral);
            [peripheral discoverServices:otpServices];
        }
    }
    NSLog(@"scanning...");
    [trayItem setTitle:@"Scanning..."];
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
    NSLog(@"known...");
    for (CBPeripheral* peripheral in peripherals) {
            NSLog(@"peripheral... %@", peripheral.UUID);
        [discoveredPeripherals addObject:peripheral];
        [peripheral setDelegate:self];
        [peripheral discoverServices:nil];
        [manager connectPeripheral:peripheral options:nil];
        [manager stopScan];
    }
}

/*
 *  centralManager:didRetrieveConnectedPeripherals:
 *
 *  Discussion:
 *      Invoked when the central retrieved the list of peripherals currently connected to the system.
 *      See the -[retrieveConnectedPeripherals] method for more information.
 *
 */
- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
    NSLog(@"periph conn");
    for (CBPeripheral* peripheral in peripherals) {
        NSLog(@"peripheral... %@", peripheral.UUID);
    }
}


- (void)statesupdated {
    if (manager.state == CBCentralManagerStatePoweredOn) {
        [self.connectToiPhoneMenu setEnabled:YES];
        [self.getOTPButton setEnabled:NO];
    } else {
        [self.connectToiPhoneMenu setEnabled:NO];
        [self.getOTPButton setEnabled:NO];
        NSLog(@"Central Manager error: %ld", manager.state);
        [trayItem setTitle:@"Bluetooth unavailable..."];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    [self statesupdated];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"%@ -- %@ at @ RSSI %@", peripheral.name, advertisementData, RSSI);
    [manager retrieveConnectedPeripherals];
    
    if (![discoveredPeripherals containsObject:peripheral]) {
        [discoveredPeripherals addObject:peripheral];
        [manager connectPeripheral:peripheral options:nil];

        NSLog(@"Connecting...");
        [trayItem setTitle:@"Connecting..."];        
    }
}


- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected! %@ - %@", peripheral.name, peripheral.UUID);

    [manager stopScan];

    
    [self.getOTPButton setEnabled:YES];
    [self.connectToiPhoneMenu setEnabled:NO];
    [peripheral setDelegate:self];
    [peripheral discoverServices:otpServices];
    [manager retrievePeripherals:nil];
    [manager retrieveConnectedPeripherals];

}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
//        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:otpCharacteristics
                                 forService:service];
    }
}


/*
 *  peripheral:didDiscoverCharacteristics:error:
 *
 *  Discussion:
 *      Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 *      If successful, "error" is nil and discovered characteristics, if any, have been merged into the
 *      "characteristics" property of the service.
 *      If unsuccessful, "error" is set with the encountered failure.
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error didDiscoverCharacteristicsForService: %@", error);
        return;
    }
    
    // force pairing
    for (CBCharacteristic *characteristic in service.characteristics) {
        [peripheral readValueForCharacteristic:characteristic];
    }
}

- (CFStringRef)screateStringForKey:(CGKeyCode) keyCode {
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData =
    (CFDataRef)TISGetInputSourceProperty(currentKeyboard,
                                         kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout =
    (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    
    UInt32 keysDown = 0;
    UniChar chars[4];
    UniCharCount realLength;
    
    UCKeyTranslate(keyboardLayout,
                   keyCode,
                   kUCKeyActionDisplay,
                   0,
                   LMGetKbdType(),
                   kUCKeyTranslateNoDeadKeysBit,
                   &keysDown,
                   sizeof(chars) / sizeof(chars[0]),
                   &realLength,
                   chars);
    CFRelease(currentKeyboard);
    
    return CFStringCreateWithCharacters(kCFAllocatorDefault, chars, 1);
}


- (CGKeyCode)getkeyCodeForChar:(const char) c {
    static CFMutableDictionaryRef charToCodeDict = NULL;
    CGKeyCode code;
    UniChar character = c;
    CFStringRef charStr = NULL;
    
    /* Generate table of keycodes and characters. */
    if (charToCodeDict == NULL) {
        size_t i;
        charToCodeDict = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                   128,
                                                   &kCFCopyStringDictionaryKeyCallBacks,
                                                   NULL);
        if (charToCodeDict == NULL) return UINT16_MAX;
        
        /* Loop through every keycode (0 - 127) to find its current mapping. */
        for (i = 0; i < 128; ++i) {
            CFStringRef string = [self screateStringForKey:(CGKeyCode)i];
            if (string != NULL) {
                CFDictionaryAddValue(charToCodeDict, string, (const void *)i);
                CFRelease(string);
            }
        }
    }
    
    charStr = CFStringCreateWithCharacters(kCFAllocatorDefault, &character, 1);
    
    /* Our values may be NULL (0), so we need to use this function. */
    if (!CFDictionaryGetValueIfPresent(charToCodeDict, charStr,
                                       (const void **)&code)) {
        code = UINT16_MAX;
    }
    
    CFRelease(charStr);
    return code;
}

- (void)keyIn:(NSString *)otpCode {
    for (int i = 0; i < [otpCode length]; i++) {
        CGKeyCode c = [self getkeyCodeForChar:[otpCode characterAtIndex:i]];
        
        CGEventRef down = CGEventCreateKeyboardEvent(NULL, c, true);
        CGEventPost(kCGHIDEventTap, down);
        CFRelease(down);
        
        CGEventRef up = CGEventCreateKeyboardEvent(NULL, c, false);
        CGEventPost(kCGHIDEventTap, up);
        CFRelease(up);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error didUpdateValueForCharacteristic:  %@ %@", characteristic, error);
        return;
    }
    
    NSString* otpCode = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    self.lastData = otpCode;
    self.lastPeripheral = peripheral;
    
    if (self.typeItOut) {
        [peripheral readRSSI];
        [trayItem setTitle:@"maybe"];
    } else {
        if ([[trayItem title] isEqualToString:@"Connecting..."]) {
            [trayItem setTitle:@"Blauth"];
        }
    }
}

- (NSString *)scoreFromRSSI:(int)x {
    if (x < -70) {
        return @"freezing";
    } else if (x >= -70 && x < -60) {
        return @"cold";
    } else if (x >= -60 && x < -50) {
        return @"warm";
    } else if (x >= -50) {
        return @"hot";
    } else {
        return [NSString stringWithFormat:@"%d", x];
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error{
    if (error) {
        NSLog(@"Error peripheralDidUpdateRSSI:  %@ %@", peripheral, error);
        return;
    }
    
    int threshold_min = -40; // lower than that, too far away
    
    NSLog(@"Peripheral at %@", peripheral.RSSI);

    if (self.typeItOut) {
        if ([peripheral.RSSI intValue] > threshold_min) {
            [self keyIn:self.lastData];
            self.typeItOut = NO;
            [trayItem setTitle:@"Blauth"];
            // 
        } else {
            NSString *score = [self scoreFromRSSI:[peripheral.RSSI intValue]];
            [trayItem setTitle:[NSString stringWithFormat:@"iPhone too far away (%@)", score]];
            [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(readRSSI) userInfo:nil repeats:NO];
        }
    }
}

- (void)readRSSI {
    [self.lastPeripheral readRSSI];
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    NSLog(@"error while connecting to %@: %@", peripheral, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"disconnected from %@ because of %@", peripheral, error);
}

- (IBAction)quitClicked:(id)sender {
    [[NSApplication sharedApplication] terminate:nil];
}

- (IBAction)getOTP2Clicked:(id)sender {
    self.typeItOut = YES;
    if ([discoveredPeripherals count] == 0) {
        [trayItem setTitle:@"No iPhones connected..."];        
    } else {
        for (CBPeripheral* peripheral in discoveredPeripherals) {
            NSLog(@"Attempting %@", peripheral);
            [peripheral setDelegate:self];
            [peripheral discoverServices:otpServices];
        }
        NSLog(@"scanning2...");
        [trayItem setTitle:@"Reaching out to iPhone..."];
    }
}


@end
