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

#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

@implementation HJTaskSetter {
    pthread_mutex_t _lock;
    HJTaskKey _key;
    HJTaskOperation *_operation;
    int32_t _sentinel;
}

- (void)dealloc {
    // NSLog(@"HJTask_Setter_dealloc");
    
    OSAtomicIncrement32(&_sentinel);
    _operation = nil;
    pthread_mutex_destroy(&_lock);
}

- (instancetype)init {
    self = [super init];
    pthread_mutex_init(&_lock, NULL);
    return self;
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
                     operationQueue:(NSOperationQueue *)operationQueue
                           progress:(nullable HJTaskProgressBlock)progress
                         completion:(nullable HJTaskCompletionBlock)completion {
    if (sentinel != _sentinel) {
        NSError *error = [NSError errorWithDomain:@"com.hj.task"
                                             code:-1
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Failed to init Sentinel" }];
        if (completion) completion(key, HJTaskStageFinished, nil, error);
        return _sentinel;
    }
    
    HJTaskOperation *operation = [[HJTaskOperation alloc] initWithKey:key
                                                             executor:executor
                                                             progress:progress
                                                           completion:completion];
    
    if (!operation) {
        NSError *error = [NSError errorWithDomain:@"com.hj.task"
                                             code:-1
                                         userInfo:@{ NSLocalizedDescriptionKey : @"HJTaskOperation create failed." }];
        if (completion) completion(key, HJTaskStageFinished, nil, error);
        return _sentinel;
    }
    
    Lock();
    [operationQueue addOperation:operation];
    
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
