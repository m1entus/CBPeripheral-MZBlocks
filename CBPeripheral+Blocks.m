//
//  CBPeripheral+Blocks.m
//  iBeaconClient
//
//  Created by Michał Zaborowski on 29.01.2014.
//  Copyright (c) 2014 Michał Zaborowski. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "CBPeripheral+Blocks.h"
#import "CBUUID+String.h"
#import <objc/runtime.h>

static void MZSwizzleMethod(Class class, SEL originalMethodSelector, SEL newMethodSelector) {

    Method originalMethod = class_getInstanceMethod(class, originalMethodSelector);
    Method newMethod = class_getInstanceMethod(class, newMethodSelector);

    IMP originalMethodImplementation = method_getImplementation(originalMethod);
    IMP newMethodImplementation = method_getImplementation(newMethod);

    BOOL methodAdded = class_addMethod(class,
                                       originalMethodSelector,
                                       newMethodImplementation,
                                       method_getTypeEncoding(newMethod));

    if(methodAdded) {
        class_replaceMethod(class,
                            newMethodSelector,
                            originalMethodImplementation,
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

@interface NSArray (MZFirstObject)
- (id)mz_firstObject;
@end

@implementation NSArray (MZFirstObject)
- (id)mz_firstObject
{
    if (self.count > 0) {
        return [self objectAtIndex:0];
    }
    return nil;
}
@end

void objc_setAssociatedObject(id object,
                              const void *key,
                              id value,
                              objc_AssociationPolicy policy);

@implementation CBPeripheral (MZAssociations)

- (void)setMz_realDelegate:(id<CBPeripheralDelegate>)mz_realDelegate
{
    objc_setAssociatedObject(self,
                             @selector(mz_realDelegate),
                             mz_realDelegate,
                             OBJC_ASSOCIATION_ASSIGN);
}

- (id<CBPeripheralDelegate>)mz_realDelegate
{
    return objc_getAssociatedObject(self, @selector(mz_realDelegate));
}

- (void)setMz_discoveryBlock:(MZPeripheralDiscoverServicesCompletionBlock)mz_discoveryBlock
{
    objc_setAssociatedObject(self, @selector(mz_discoveryBlock), mz_discoveryBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (MZPeripheralDiscoverServicesCompletionBlock)mz_discoveryBlock
{
    return objc_getAssociatedObject(self, @selector(mz_discoveryBlock));
}

- (void)setMz_writeMessageCompletionBlocksQueue:(NSMutableArray *)mz_writeMessageCompletionBlocksQueue
{
    objc_setAssociatedObject(self, @selector(mz_writeMessageCompletionBlocksQueue), mz_writeMessageCompletionBlocksQueue, OBJC_ASSOCIATION_RETAIN);
}

/* So you can use writeValue multiple times, and CB will properly queue the calls for you, i.e.
 it will wait for the response at the ATT layer before the next write.
 And the delegate callbacks are guaranteed to be in the same order the writes are executed.
 */
- (NSMutableArray *)mz_writeMessageCompletionBlocksQueue
{
    if (!objc_getAssociatedObject(self, @selector(mz_writeMessageCompletionBlocksQueue))) {
        self.mz_writeMessageCompletionBlocksQueue = [[NSMutableArray alloc] init];
    }
    return objc_getAssociatedObject(self, @selector(mz_writeMessageCompletionBlocksQueue));
}

- (void)setMz_discoveryCharacteristicForServiceCompletionBlocksDictionary:(NSMutableDictionary *)mz_discoveryCharacteristicForServiceCompletionBlocksDictionary
{
    objc_setAssociatedObject(self,
                             @selector(mz_discoveryCharacteristicForServiceCompletionBlocksDictionary),
                             mz_discoveryCharacteristicForServiceCompletionBlocksDictionary,
                             OBJC_ASSOCIATION_RETAIN);
}

- (NSMutableDictionary *)mz_discoveryCharacteristicForServiceCompletionBlocksDictionary
{
    if (!objc_getAssociatedObject(self, @selector(mz_discoveryCharacteristicForServiceCompletionBlocksDictionary))) {
        self.mz_discoveryCharacteristicForServiceCompletionBlocksDictionary = [[NSMutableDictionary alloc] init];
    }
    return objc_getAssociatedObject(self, @selector(mz_discoveryCharacteristicForServiceCompletionBlocksDictionary));
}

@end


@implementation CBPeripheral (MZBlocks)

+ (void)load
{
    MZSwizzleMethod(self, @selector(setDelegate:), @selector(setMz_delegate:));
    MZSwizzleMethod(self, @selector(respondsToSelector:), @selector(mz_respondsToSelector:));
    MZSwizzleMethod(self, @selector(methodSignatureForSelector:), @selector(mz_methodSignatureForSelector:));
    MZSwizzleMethod(self, @selector(forwardingTargetForSelector:), @selector(mz_forwardingTargetForSelector:));
}

#pragma mark - Getters/Setters

- (void)setMz_delegate:(id <CBPeripheralDelegate>)swizzledDelegate
{
    [self setMz_delegate:self];

    self.mz_realDelegate = swizzledDelegate;
}

#pragma mark - Public

- (void)discoverServices:(NSArray *)serviceUUIDs completionBlock:(MZPeripheralDiscoverServicesCompletionBlock)discoveryBlock
{
    self.mz_discoveryBlock = discoveryBlock;

    [self discoverServices:serviceUUIDs];
}

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic
              type:(CBCharacteristicWriteType)type
   completionBlock:(MZPeripheralWriteValueCompletionBlock)completionBlock
{
    if (type == CBCharacteristicWriteWithResponse && completionBlock) {
        [self.mz_writeMessageCompletionBlocksQueue addObject:completionBlock];
    }
    [self writeValue:data forCharacteristic:characteristic type:type];
}

- (void)discoverCharacteristics:(NSArray *)characteristicUUIDs
                     forService:(CBService *)service
                completionBlock:(MZPeripheralDiscoverCharacteristicsCompletionBlock)completionBlock
{
    if (completionBlock) {
        [self.mz_discoveryCharacteristicForServiceCompletionBlocksDictionary setObject:completionBlock forKey:[service.UUID mz_stringValue]];
    }
    [self discoverCharacteristics:characteristicUUIDs forService:service];
}

#pragma mark - Delegate Forwarder

- (BOOL)mz_respondsToSelector:(SEL)selector
{
    return [self mz_respondsToSelector:selector] || [self.mz_realDelegate respondsToSelector:selector];
}

- (NSMethodSignature *)mz_methodSignatureForSelector:(SEL)selector
{
    if ([self mz_methodSignatureForSelector:selector]) {
        return [self mz_methodSignatureForSelector:selector];
    }

    return [(id)self.mz_realDelegate methodSignatureForSelector:selector];
}

- (id)mz_forwardingTargetForSelector:(SEL)selector
{
    if ([self.mz_realDelegate respondsToSelector:selector]) {
        return self.mz_realDelegate;
    }

    return [self mz_forwardingTargetForSelector:selector];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (self.mz_discoveryBlock) {
        self.mz_discoveryBlock(peripheral.services,error);
    } else if ([self.mz_realDelegate respondsToSelector:_cmd]) {
        [self.mz_realDelegate peripheral:peripheral didDiscoverServices:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    MZPeripheralWriteValueCompletionBlock completionBlock = [self.mz_writeMessageCompletionBlocksQueue mz_firstObject];
    if (completionBlock) {
        [self.mz_writeMessageCompletionBlocksQueue removeObject:completionBlock];
        completionBlock(error);

    } else if ([self.mz_realDelegate respondsToSelector:_cmd]) {
        [self.mz_realDelegate peripheral:peripheral didWriteValueForCharacteristic:characteristic error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    MZPeripheralDiscoverCharacteristicsCompletionBlock completionBlock = self.mz_discoveryCharacteristicForServiceCompletionBlocksDictionary[[service.UUID mz_stringValue]];
    if (completionBlock) {
        [self.mz_discoveryCharacteristicForServiceCompletionBlocksDictionary removeObjectForKey:[service.UUID mz_stringValue]];
        completionBlock(service,error);

    } else if ([self.mz_realDelegate respondsToSelector:_cmd]) {
        [self.mz_realDelegate peripheral:peripheral didDiscoverCharacteristicsForService:service error:error];
    }
}

@end