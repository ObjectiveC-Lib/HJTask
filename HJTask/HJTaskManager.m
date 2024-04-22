//
//  HJTaskManager.m
//  HJTask
//
//  Created by navy on 2021/1/4.
//  Copyright © 2021 navy. All rights reserved.
//

#import "HJTaskManager.h"
#import <pthread/pthread.h>
#import "HJTaskSetter.h"

#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

@interface HJTaskManager ()
@property (nonatomic, strong) NSMutableDictionary <HJTaskKey, HJTaskSetter *> *setters;
@end

@implementation HJTaskManager {
    pthread_mutex_t _lock;
    dispatch_queue_t _queue;
    NSOperationQueue *_operationQueue;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, NULL);
        _queue = dispatch_queue_create("com.hj.task.setter", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        _operationQueue = [NSOperationQueue new];
        if ([_operationQueue respondsToSelector:@selector(setQualityOfService:)]) {
            _operationQueue.qualityOfService = NSQualityOfServiceBackground;
        }
        _setters = [NSMutableDictionary dictionary];
    }
    return self;
}

- (HJTaskKey)executor:(nullable NSObject<HJTaskProtocol> *)executor
             progress:(nullable HJTaskProgressBlock)progress
           completion:(nullable HJTaskCompletionBlock)completion {
    if (!executor) return HJTaskKeyInvalid;
    
    Lock();
    _operationQueue.maxConcurrentOperationCount = executor.taskMaxConcurrentCount>0?executor.taskMaxConcurrentCount:-1;
    HJTaskKey key = executor.taskKey;
    HJTaskSetter *setter = _setters[key];
    if (!setter) {
        setter = [HJTaskSetter new];
        _setters[key] = setter;
    }
    int32_t sentinel = [setter cancelWithNewKey:key];
    Unlock();
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_queue, ^{
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
            __strong typeof(weakSelf) self = weakSelf;
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
                                        operationQueue:_operationQueue
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

- (void)cancelAll {
    Lock();
    [_setters enumerateKeysAndObjectsUsingBlock:^(HJTaskKey key, HJTaskSetter *setter, BOOL * stop) {
        if (setter) [setter cancel];
    }];
    Unlock();
}

@end
