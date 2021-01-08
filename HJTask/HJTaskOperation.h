//
//  HJTaskOperation.h
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HJTaskProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol HJTaskProtocol;

@interface HJTaskOperation : NSOperation
@property (nonatomic, strong, readonly) HJTaskKey key;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithKey:(HJTaskKey)key
                   executor:(nullable NSObject<HJTaskProtocol> *)executor
                   progress:(nullable HJTaskProgressBlock)progress
                 completion:(nullable HJTaskCompletionBlock)completion NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
