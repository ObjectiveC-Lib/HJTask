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

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)


@interface HJTaskManager ()
@property (nonatomic, strong) NSMutableDictionary *setters;
@end

@implementation HJTaskManager {
    dispatch_semaphore_t _lock;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _setters = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static HJTaskManager *sharedInstance;
    dispatch_once(&once, ^ {
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (HJTaskKey)executor:(nullable NSObject<HJTaskProtocol> *)executor
             progress:(nullable HJTaskProgressBlock)progress
           completion:(nullable HJTaskCompletionBlock)completion {
    if (!executor) return HJTaskKeyInvalid;
    
    Lock();
    HJTaskKey key = executor.taskKey;
    HJTaskSetter *setter = _setters[key];
    if (!setter) {
        setter = [HJTaskSetter new];
        _setters[key] = setter;
    }
    int32_t sentinel = [setter cancelWithNewKey:key];
    Unlock();
    
    __weak typeof(self) weakself = self;
    dispatch_async([HJTaskSetter setterQueue], ^{
        HJTaskProgressBlock _progress = nil;
        if (progress) {
            _progress = ^(HJTaskKey key, NSProgress *taskProgress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(key, taskProgress);
                });
            };
        }
        
        __block int32_t newSentinel = 0;
        __block __weak typeof(setter) weakSetter = nil;
        HJTaskCompletionBlock _completion = ^(HJTaskKey key, HJTaskStage stage, id callbackInfo, NSError *error) {
            __strong typeof(weakself) self = weakself;
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL sentinelChanged = weakSetter && weakSetter.sentinel != newSentinel;
                if (completion) {
                    if (sentinelChanged) {
                        completion(key, HJTaskStageCancelled, callbackInfo, error);
                    } else {
                        completion(key, stage, callbackInfo, error);
                    }
                    Lock();
                    [self.setters removeObjectForKey:key];
                    Unlock();
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
    
    return key;
}

- (void)cancelWithKey:(HJTaskKey)key {
    if (key == HJTaskKeyInvalid) return;
    
    Lock();
    HJTaskSetter *setter = _setters[key];
    if (setter) [setter cancel];
    Unlock();
}

@end
