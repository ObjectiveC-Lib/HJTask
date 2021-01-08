//
//  HJTaskSetter.h
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HJTaskProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface HJTaskSetter : NSObject
@property (nonatomic, readonly, nullable) NSString *key;
@property (nonatomic, readonly) int32_t sentinel;

+ (dispatch_queue_t)setterQueue;

- (int32_t)setOperationWithSentinel:(int32_t)sentinel
                           executor:(nullable NSObject<HJTaskProtocol> *)executor
                                key:(HJTaskKey)key
                           progress:(nullable HJTaskProgressBlock)progress
                         completion:(nullable HJTaskCompletionBlock)completion;

- (int32_t)cancel;
- (int32_t)cancelWithNewKey:(HJTaskKey)key;
@end

NS_ASSUME_NONNULL_END
