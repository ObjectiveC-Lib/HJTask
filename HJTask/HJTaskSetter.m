//
//  HJTaskSetter.m
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import "HJTaskSetter.h"
#import <libkern/OSAtomic.h>
#import <pthread/pthread.h>
#import "HJTaskOperation.h"
#import "HJTaskQueue.h"

#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

@implementation HJTaskSetter {
    pthread_mutex_t _lock;
    HJTaskKey _key;
    HJTaskOperation *_operation;
    int32_t _sentinel;
}

- (void)dealloc {
    OSAtomicIncrement32(&_sentinel);
    _operation = nil;
}

- (instancetype)init {
    self = [super init];
    pthread_mutex_init(&_lock, NULL);
    return self;
}

+ (dispatch_queue_t)setterQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.hj.task.setter", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    });
    return queue;
}

- (HJTaskKey)key {
    Lock();
    HJTaskKey key = _key;
    Unlock();
    return key;
}

- (int32_t)setOperationWithSentinel:(int32_t)sentinel
                           executor:(nullable NSObject<HJTaskProtocol> *)executor
                                key:(HJTaskKey)key
                           progress:(nullable HJTaskProgressBlock)progress
                         completion:(nullable HJTaskCompletionBlock)completion {
    if (sentinel != _sentinel) {
        NSError *error = [NSError errorWithDomain:@"com.hj.task"
                                             code:-1
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Failed to init Sentinel" }];
        if (completion) completion(key, HJTaskStageFinished, nil, error);
        return _sentinel;
    }
    
    HJTaskOperation *operation = [[HJTaskQueue sharedInstance] executor:executor
                                                                    key:key
                                                               progress:progress
                                                             completion:completion];
    
    if (!operation && completion) {
        NSError *error = [NSError errorWithDomain:@"com.hj.task"
                                             code:-1
                                         userInfo:@{ NSLocalizedDescriptionKey : @"HJTaskOperation create failed." }];
        completion(key, HJTaskStageFinished, nil, error);
    }
    
    Lock();
    if (sentinel == _sentinel) {
        if (_operation) {
            [_operation cancel];
        }
        _operation = operation;
        sentinel = OSAtomicIncrement32(&_sentinel);
    } else {
        [operation cancel];
    }
    Unlock();
    
    return sentinel;
}

- (int32_t)cancel {
    return [self cancelWithNewKey:nil];
}

- (int32_t)cancelWithNewKey:(HJTaskKey)key {
    int32_t sentinel;
    
    Lock();
    if (_operation) {
        [_operation cancel];
        _operation = nil;
    }
    
    _key = key;
    
    sentinel = OSAtomicIncrement32(&_sentinel);
    Unlock();
    
    return sentinel;
}

@end
