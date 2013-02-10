#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


#define OTPOverBluetoothService @"B8565F34-A174-4B8F-8F83-AB401D37D288"
#define OTPOverBluetoothAvailableAccounts @"75EA0F1B-1349-4A34-AB18-90B95C74ADF1"
#define OTPOverBluetoothAccountOTP @"54365900-202F-4E2A-BE29-491DCD28B251"


@protocol OTPBluetoothServiceProvider

- (NSString *)getOTPForAccount:(NSString *)account;

@end


@interface OTPBluetoothService : NSObject <CBPeripheralManagerDelegate>

@property (retain) id<OTPBluetoothServiceProvider> provider;
@property int counter;
@property BOOL status;
@property (strong, nonatomic) CBPeripheralManager       *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic   *transferCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic   *accountsCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic   *otpTransactionCharacteristic;
@property (strong, nonatomic) NSData                    *dataToSend;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;

- (void)statusChanged;
- (id)initWithProvider:(id<OTPBluetoothServiceProvider>)provider;
- (void)start;
- (void)stop;

@end


