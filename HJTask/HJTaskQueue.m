//
//  HJTaskQueue.m
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import "HJTaskQueue.h"
#import "HJTaskOperation.h"

@implementation HJTaskQueue

- (instancetype)init {
    @throw [NSException exceptionWithName:@"HJTaskManager init error"
                                   reason:@"Use the designated initializer to init."
                                 userInfo:nil];
    return [self initWithQueue:nil];
}

- (instancetype)initWithQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (!self) return nil;
    _queue = queue;
    return self;
}

+ (instancetype)sharedInstance {
    static HJTaskQueue *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperationQueue *queue = [NSOperationQueue new];
        if ([queue respondsToSelector:@selector(setQualityOfService:)]) {
            queue.qualityOfService = NSQualityOfServiceBackground;
        }
        manager = [[self alloc] initWithQueue:queue];
    });
    return manager;
}

- (nullable HJTaskOperation *)executor:(nullable NSObject<HJTaskProtocol> *)executor
                                   key:(NSString *)key
                              progress:(nullable HJTaskProgressBlock)progress
                            completion:(nullable HJTaskCompletionBlock)completion {
    HJTaskOperation *operation = [[HJTaskOperation alloc] initWithKey:key
                                                             executor:executor
                                                             progress:progress
                                                           completion:completion];
    if (operation) {
        NSOperationQueue *queue = _queue;
        if (queue) {
            [queue addOperation:operation];
        } else {
            [operation start];
        }
    }
    return operation;
}

@end
