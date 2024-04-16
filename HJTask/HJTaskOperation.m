//
//  HJTaskOperation.m
//  HJTask
//
//  Created by navy on 2019/3/13.
//  Copyright © 2019 navy. All rights reserved.
//

#import "HJTaskOperation.h"
#import <libkern/OSAtomic.h>

/// Returns nil in App Extension.
static UIApplication *HJSharedApplication() {
    static BOOL isAppExtension = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"UIApplication");
        if(!cls || ![cls respondsToSelector:@selector(sharedApplication)]) isAppExtension = YES;
        if ([[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"]) isAppExtension = YES;
    });
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    return isAppExtension ? nil : [UIApplication performSelector:@selector(sharedApplication)];
#pragma clang diagnostic pop
}

@interface HJTaskOperation()
@property (readwrite, getter=isExecuting) BOOL executing;
@property (readwrite, getter=isFinished) BOOL finished;
@property (readwrite, getter=isCancelled) BOOL cancelled;
@property (readwrite, getter=isStarted) BOOL started;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskID;
@property (nonatomic, strong) NSObject<HJTaskProtocol> *executor;
@property (nonatomic, copy) HJTaskProgressBlock progress;
@property (nonatomic, copy) HJTaskCompletionBlock completion;
@end

@implementation HJTaskOperation
@synthesize executing = _executing;
@synthesize finished = _finished;
@synthesize cancelled = _cancelled;

/// Task thread entry point.
+ (void)taskThreadMain:(id)object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.hj.task"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

/// Global task thread
+ (NSThread *)taskThread {
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(taskThreadMain:) object:nil];
        if ([thread respondsToSelector:@selector(setQualityOfService:)]) {
            thread.qualityOfService = NSQualityOfServiceBackground;
        }
        [thread start];
    });
    return thread;
}

/// Global queue, used for source reading
+ (dispatch_queue_t)taskQueue {
#define MAX_QUEUE_COUNT 16
    static int queueCount;
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static int32_t counter = 0;
    dispatch_once(&onceToken, ^{
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            for (NSUInteger i = 0; i < queueCount; i++) {
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
                queues[i] = dispatch_queue_create("com.hj.task.read", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                queues[i] = dispatch_queue_create("com.hj.task.read", DISPATCH_QUEUE_SERIAL);
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            }
        }
    });
    int32_t cur = OSAtomicIncrement32(&counter);
    if (cur < 0) cur = -cur;
    return queues[(cur) % queueCount];
#undef MAX_QUEUE_COUNT
}

- (void)dealloc {
    // NSLog(@"HJTaskOperation_dealloc");
    
    [_lock lock];
    if ([self isExecuting]) {
        if (_executor) {
            [_executor cancelTask];
        } else {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorCancelled
                                             userInfo:@{ NSLocalizedDescriptionKey : @"HJTaskOperation cancelled Task" }];
            if (_completion) {
                @autoreleasepool {
                    _completion(_key, HJTaskStageCancelled, nil, error);
                }
            }
            self.cancelled = YES;
            [self finishOperation];
        }
    } else {
        [self finishOperation];
    }
    [_lock unlock];
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"HJTaskOperation init error"
                                   reason:@"HJTaskOperation must be initialized with a request. Use the designated initializer to init."
                                 userInfo:nil];
    return [self initWithKey:HJTaskKeyInvalid executor:nil progress:nil completion:nil];
}

- (instancetype)initWithKey:(HJTaskKey)key
                   executor:(nullable NSObject<HJTaskProtocol> *)executor
                   progress:(nullable HJTaskProgressBlock)progress
                 completion:(nullable HJTaskCompletionBlock)completion  {
    self = [super init];
    if (!self) return nil;
    
    _executor = executor;
    _key = key;
    _progress = progress;
    _completion = completion;
    _executing = NO;
    _finished = NO;
    _cancelled = NO;
    _taskID = UIBackgroundTaskInvalid;
    _lock = [NSRecursiveLock new];
    
    return self;
}

#pragma mark - Runs in operation thread

- (void)endBackgroundTask {
    [_lock lock];
    if (_taskID != UIBackgroundTaskInvalid) {
        [HJSharedApplication() endBackgroundTask:_taskID];
        _taskID = UIBackgroundTaskInvalid;
    }
    [_lock unlock];
}

- (void)finishOperation {
    self.executing = NO;
    self.finished = YES;
    [self endBackgroundTask];
}

- (void)cancelOperation {
    @autoreleasepool {
        if (_executor) {
            [_executor cancelTask];
        } else {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorCancelled
                                             userInfo:@{ NSLocalizedDescriptionKey : @"HJTaskOperation cancelled Task" }];
            if (_completion) _completion(_key, HJTaskStageCancelled, nil, error);
            
            self.cancelled = YES;
            [self finishOperation];
        }
    }
}

- (void)startOperation {
    if ([self isCancelled]) return;
    
    @autoreleasepool {
        __weak typeof(self) _self = self;
        dispatch_async([self.class taskQueue], ^{
            __strong typeof(_self) self = _self;
            if (!self || [self isCancelled]) return;
            [self performSelector:@selector(startTask:)
                         onThread:[self.class taskThread]
                       withObject:nil
                    waitUntilDone:NO];
        });
    }
}

- (void)startTask:(id)object {
    if ([self isCancelled]) return;
    
    @autoreleasepool {
        [_lock lock];
        if (![self isCancelled]) {
            if (_executor) {
                [_executor startTask];
            }
        }
        [_lock unlock];
    }
}

#pragma mark - Override NSOperation

- (void)start {
    @autoreleasepool {
        [_lock lock];
        self.started = YES;
        
        if ([self isCancelled]) {
            [self performSelector:@selector(cancelOperation)
                         onThread:[[self class] taskThread]
                       withObject:nil
                    waitUntilDone:NO
                            modes:@[NSDefaultRunLoopMode]];
        } else if ([self isReady] && ![self isFinished] && ![self isExecuting]) {
            self.executing = YES;
            
            if (_executor) {
                __weak typeof(self) _self = self;
                _executor.taskProgress = ^(HJTaskKey key, NSProgress * _Nullable progress) {
                    __strong typeof(_self) self = _self;
                    if (self->_progress) self->_progress(key, progress);
                };
                _executor.taskCompletion = ^(HJTaskKey key,
                                             HJTaskStage stage,
                                             id _Nullable callbackInfo,
                                             NSError * _Nullable error) {
                    __strong typeof(_self) self = _self;
                    if (self->_completion) self->_completion(key, stage, callbackInfo, error);
                    [self performSelector:@selector(finishOperation)
                                 onThread:[self.class taskThread]
                               withObject:nil
                            waitUntilDone:NO];
                };
                
                [self performSelector:@selector(startOperation)
                             onThread:[[self class] taskThread]
                           withObject:nil
                        waitUntilDone:NO
                                modes:@[NSDefaultRunLoopMode]];
                
                BOOL allowBackground = _executor.taskAllowBackground;
                if (allowBackground && HJSharedApplication()) {
                    __weak __typeof__ (self) _self = self;
                    if (_taskID == UIBackgroundTaskInvalid) {
                        _taskID = [HJSharedApplication() beginBackgroundTaskWithExpirationHandler:^{
                            __strong __typeof (_self) self = _self;
                            if (self) {
                                [self cancel];
                            }
                        }];
                    }
                }
            } else {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                     code:NSURLErrorFileDoesNotExist
                                                 userInfo:@{ NSLocalizedDescriptionKey : @"HJTaskOperation executor in nil" }];
                if (_completion) _completion(_key, HJTaskStageFinished, nil, error);
                [self performSelector:@selector(finishOperation)
                             onThread:[self.class taskThread]
                           withObject:nil
                        waitUntilDone:NO];
            }
        }
        [_lock unlock];
    }
}

- (void)cancel {
    [_lock lock];
    if (![self isCancelled]) {
        [super cancel];
        if ([self isExecuting]) {
            [self performSelector:@selector(cancelOperation)
                         onThread:[[self class] taskThread]
                       withObject:nil
                    waitUntilDone:NO
                            modes:@[NSDefaultRunLoopMode]];
        } else {
            self.cancelled = YES;
            if (self.started) {
                self.finished = YES;
            }
        }
    }
    [_lock unlock];
}

- (void)setExecuting:(BOOL)executing {
    [_lock lock];
    if (_executing != executing) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
    [_lock unlock];
}

- (BOOL)isExecuting {
    [_lock lock];
    BOOL executing = _executing;
    [_lock unlock];
    return executing;
}

- (void)setFinished:(BOOL)finished {
    [_lock lock];
    if (_finished != finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
    [_lock unlock];
}

- (BOOL)isFinished {
    [_lock lock];
    BOOL finished = _finished;
    [_lock unlock];
    return finished;
}

- (void)setCancelled:(BOOL)cancelled {
    [_lock lock];
    if (_cancelled != cancelled) {
        [self willChangeValueForKey:@"isCancelled"];
        _cancelled = cancelled;
        [self didChangeValueForKey:@"isCancelled"];
    }
    [_lock unlock];
}

- (BOOL)isCancelled {
    [_lock lock];
    BOOL cancelled = _cancelled;
    [_lock unlock];
    return cancelled;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isAsynchronous {
    return YES;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"isExecuting"] ||
        [key isEqualToString:@"isFinished"] ||
        [key isEqualToString:@"isCancelled"]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (NSString *)description {
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@: %p ",self.class, self];
    [string appendFormat:@" executing:%@", [self isExecuting] ? @"YES" : @"NO"];
    [string appendFormat:@" finished:%@", [self isFinished] ? @"YES" : @"NO"];
    [string appendFormat:@" cancelled:%@", [self isCancelled] ? @"YES" : @"NO"];
    [string appendString:@">"];
    return string;
}

@end
