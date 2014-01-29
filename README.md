CBPeripheral-MZBlocks
=====================

Category on CBPeripheral to use inline block callbacks instead of delegate callbacks.

``` objective-c
typedef void(^MZPeripheralDiscoverServicesCompletionBlock)(NSArray *services, NSError *error);
typedef void(^MZPeripheralWriteValueCompletionBlock)(NSError *error);
typedef void(^MZPeripheralDiscoverCharacteristicsCompletionBlock)(CBService *service, NSError *error);

@interface CBPeripheral (MZAssociations)
@property (strong, readonly) NSMutableDictionary *discoveryCharacteristicForServiceCompletionBlocksDictionary;
@property (strong, readonly) NSMutableArray *writeMessageCompletionBlocksQueue;
@end

@interface CBPeripheral (MZBlocks) <CBPeripheralDelegate>

- (void)discoverServices:(NSArray *)serviceUUIDs completionBlock:(MZPeripheralDiscoverServicesCompletionBlock)discoveryBlock;

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic
                                               type:(CBCharacteristicWriteType)type
                                    completionBlock:(MZPeripheralWriteValueCompletionBlock)completionBlock;

- (void)discoverCharacteristics:(NSArray *)characteristicUUIDs
                     forService:(CBService *)service
                completionBlock:(MZPeripheralDiscoverCharacteristicsCompletionBlock)completionBlock;

@end
```