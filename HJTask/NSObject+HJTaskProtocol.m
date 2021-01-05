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

- (NSString *)taskKey {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskKey:(NSString *)taskKey {
    objc_setAssociatedObject(self, @selector(taskKey), taskKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HJTaskProgressBlock)taskProgress {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskProgress:(HJTaskProgressBlock)taskProgress {
    objc_setAssociatedObject(self, @selector(taskProgress), taskProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HJTaskResultBlock)taskResult {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTaskResult:(HJTaskResultBlock)taskResult {
    objc_setAssociatedObject(self, @selector(taskResult), taskResult, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowBackground {
    return YES;
}

- (void)startTask {
    
}

- (void)cancelTask {
    
}

@end
