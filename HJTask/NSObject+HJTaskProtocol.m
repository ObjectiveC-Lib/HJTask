//
//  NSObject+HJTaskProtocol.m
//  HJTask
//
//  Created by navy on 2021/1/5.
//  Copyright © 2021 navy. All rights reserved.
//

#import "NSObject+HJTaskProtocol.h"
#import <objc/runtime.h>

@implementation NSObject (HJTaskProtocol)

- (HJTaskKey)taskKey {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskKey:(HJTaskKey)taskKey {
    objc_setAssociatedObject(self, @selector(taskKey), taskKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HJTaskProgressBlock)taskProgress {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskProgress:(HJTaskProgressBlock)taskProgress {
    objc_setAssociatedObject(self, @selector(taskProgress), taskProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HJTaskCompletionBlock)taskCompletion {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskCompletion:(HJTaskCompletionBlock)taskCompletion {
    objc_setAssociatedObject(self, @selector(taskCompletion), taskCompletion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowBackground {
    return YES;
}

- (void)startTask {
    
}

- (void)cancelTask {
    
}

@end
