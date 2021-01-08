//
//  HJTaskQueue.h
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HJTaskProtocol.h"

@class HJTaskOperation;

NS_ASSUME_NONNULL_BEGIN

@interface HJTaskQueue : NSObject
@property (nullable, nonatomic, strong) NSOperationQueue *queue;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithQueue:(NSOperationQueue *)queue NS_DESIGNATED_INITIALIZER;
+ (instancetype)sharedInstance;

- (nullable HJTaskOperation *)executor:(nullable NSObject<HJTaskProtocol> *)executor
                                   key:(HJTaskKey)key
                              progress:(nullable HJTaskProgressBlock)progress
                            completion:(nullable HJTaskCompletionBlock)completion;
@end

NS_ASSUME_NONNULL_END
