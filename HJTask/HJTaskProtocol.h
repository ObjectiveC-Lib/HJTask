//
//  HJTaskProtocol.h
//  HJTask
//
//  Created by navy on 2020/12/30.
//  Copyright © 2020 navy. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Indicated task complete stage.
typedef NS_ENUM(NSInteger, HJTaskStage) {
    HJTaskStageProgress  = -1,
    HJTaskStageCancelled = 0,
    HJTaskStageFinished  = 1, /// (succeed or failed).
};

typedef NSString * _Nullable HJTaskKey;
static const HJTaskKey HJTaskKeyInvalid = nil;

/// size in bytes, expectedSize(-1 means unknown)
typedef void(^HJTaskProgressBlock)(NSProgress * _Nullable taskProgress);

typedef void (^HJTaskCompletionBlock)(HJTaskKey,
                                      HJTaskStage stage,
                                      NSDictionary<NSString *, id> *_Nullable callbackInfo,
                                      NSError *_Nullable error);

typedef void (^HJTaskResultBlock)(HJTaskStage stage,
                                  NSDictionary<NSString *, id> *_Nullable callbackInfo,
                                  NSError *_Nullable error);

NS_ASSUME_NONNULL_BEGIN

@protocol HJTaskProtocol <NSObject>

@optional
@property (nonatomic, copy, nullable) HJTaskKey taskKey;
@property (nonatomic, copy, nullable) HJTaskProgressBlock taskProgress;
@property (nonatomic, copy, nullable) HJTaskResultBlock taskResult;
@property (nonatomic, assign, readonly) BOOL allowBackground;

- (void)startTask;
- (void)cancelTask;

@end

NS_ASSUME_NONNULL_END
