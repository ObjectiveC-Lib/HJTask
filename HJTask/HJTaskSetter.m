//
//  HJTaskSetter.m
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import "HJTaskSetter.h"
#import <libkern/OSAtomic.h>
#import "HJTaskOperation.h"
#import "HJTaskQueue.h"

@implementation HJTaskSetter {
    dispatch_semaphore_t _lock;
    NSString *_key;
    NSOperation *_operation;
    int32_t _sentinel;
}

- (void)dealloc {
    OSAtomicIncrement32(&_sentinel);
    
    if ([_operation isExecuting]) {
        [_operation cancel];
    }
    _operation = nil;
}

- (instancetype)init {
    self = [super init];
    _lock = dispatch_semaphore_create(1);
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

- (NSString *)key {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSString *key = _key;
    dispatch_semaphore_signal(_lock);
    return key;
}

- (int32_t)setOperationWithSentinel:(int32_t)sentinel
                           executor:(nullable NSObject<HJTaskProtocol> *)executor
                                key:(nullable NSString *)key
                           progress:(nullable HJTaskProgressBlock)progress
                         completion:(nullable HJTaskCompletionBlock)completion {
    if (sentinel != _sentinel) {
        if (completion) completion(key, HJTaskStageCancelled, nil, nil);
        return _sentinel;
    }
    
    NSOperation *operation = [[HJTaskQueue sharedInstance] executor:executor
                                                                key:key
                                                           progress:progress
                                                         completion:completion];
    
    if (!operation && completion) {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"HJTaskOperation create failed." };
        completion(key, HJTaskStageFinished, nil, [NSError errorWithDomain:@"com.hj.task" code:-1 userInfo:userInfo]);
    }
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (sentinel == _sentinel) {
        if (_operation) [_operation cancel];
        _operation = operation;
        sentinel = OSAtomicIncrement32(&_sentinel);
    } else {
        [operation cancel];
    }
    dispatch_semaphore_signal(_lock);
    
    return sentinel;
}

- (int32_t)cancel {
    return [self cancelWithNewKey:nil];
}

- (int32_t)cancelWithNewKey:(nullable NSString *)key {
    int32_t sentinel;
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (_operation) {
        [_operation cancel];
        _operation = nil;
    }
    
    _key = key;
    
    sentinel = OSAtomicIncrement32(&_sentinel);
    dispatch_semaphore_signal(_lock);
    
    return sentinel;
}

@end
