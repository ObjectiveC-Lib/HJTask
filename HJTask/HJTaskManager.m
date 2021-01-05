//
//  HJTaskManager.m
//  HJTask
//
//  Created by navy on 2021/1/4.
//  Copyright © 2021 navy. All rights reserved.
//

#import "HJTaskManager.h"
#import <pthread.h>
#import "HJTaskSetter.h"

static inline void hj_dispatch_sync_on_main_queue(void (^ _Nullable block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}


@interface HJTaskManager ()
@property (nonatomic, strong) NSMutableDictionary *setters;
@end


@implementation HJTaskManager {
    dispatch_semaphore_t _lock;
}

- (id)init {
    if ((self = [super init])) {
        _lock = dispatch_semaphore_create(1);
        _setters = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (HJTaskManager *)sharedInstance {
    static dispatch_once_t once;
    static HJTaskManager *sharedInstance;
    dispatch_once(&once, ^ {
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)executor:(nullable NSObject<HJTaskProtocol> *)executor
             key:(NSString *)key
        progress:(nullable HJTaskProgressBlock)progress
      completion:(nullable HJTaskCompletionBlock)completion {
    if (!executor) return;
    if (!key) return;
    
    HJTaskSetter *setter = _setters[key];
    if (!setter) {
        setter = [HJTaskSetter new];
        dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
        _setters[key] = setter;
        dispatch_semaphore_signal(_lock);
    }
    
    int32_t sentinel = [setter cancelWithNewKey:key];
    
    hj_dispatch_sync_on_main_queue(^{
        __weak typeof(self) _self = self;
        
        dispatch_async([HJTaskSetter setterQueue], ^{
            HJTaskProgressBlock _progress = nil;
            if (progress) _progress = ^(NSProgress *taskProgress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(taskProgress);
                });
            };
            
            __block int32_t newSentinel = 0;
            __block __weak typeof(setter) weakSetter = nil;
            HJTaskCompletionBlock _completion = ^(NSString *key, HJTaskStage stage, NSDictionary *callbackInfo, NSError *error) {
                NSLog(@"key = %@", key);
                
                __strong typeof(_self) self = _self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL sentinelChanged = weakSetter && weakSetter.sentinel != newSentinel;
                    if (completion) {
                        if (sentinelChanged) {
                            completion(key, HJTaskStageCancelled, callbackInfo, error);
                        } else {
                            completion(key, stage, callbackInfo, error);
                        }
                        dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
                        [self.setters removeObjectForKey:key];
                        dispatch_semaphore_signal(self->_lock);
                    }
                });
            };
            newSentinel = [setter setOperationWithSentinel:sentinel
                                                  executor:executor
                                                       key:key
                                                  progress:_progress
                                                completion:_completion];
            weakSetter = setter;
        });
    });
}

- (void)cancelWithKey:(NSString *)key {
    HJTaskSetter *setter = _setters[key];
    if (setter) [setter cancel];
}

@end
