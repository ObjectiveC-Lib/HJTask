//
//  HJTaskProtocol.h
//  HJTask
//
//  Created by navy on 2020/12/30.
//  Copyright © 2020 navy. All rights reserved.
//

#import "HJTaskSetter.h"
#import <objc/runtime.h>

@implementation NSObject (HJTaskProtocol)

- (void)setAllowBackground:(BOOL)allowBackground {
    objc_setAssociatedObject(self, @selector(allowBackground), @(allowBackground), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowBackground {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

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

- (void)startTask {
    
}

- (void)cancelTask {
    
}

@end
