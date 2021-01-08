//
//  HJTaskManager.h
//  HJTask
//
//  Created by navy on 2021/1/4.
//  Copyright © 2021 navy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HJTaskProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface HJTaskManager : NSObject

+ (HJTaskManager *)sharedInstance;

- (HJTaskKey)executor:(nullable NSObject<HJTaskProtocol> *)executor
            preHandle:(BOOL (^)(HJTaskKey key))preHandle
             progress:(nullable HJTaskProgressBlock)progress
           completion:(nullable HJTaskCompletionBlock)completion;

- (void)cancelWithKey:(HJTaskKey)key;

@end

NS_ASSUME_NONNULL_END
