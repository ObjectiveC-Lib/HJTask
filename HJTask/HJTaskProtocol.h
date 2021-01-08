//
//  HJTaskProtocol.h
//  HJTask
//
//  Created by navy on 2020/12/30.
//  Copyright © 2020 navy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

/// Indicated task complete stage.
typedef NS_ENUM(NSInteger, HJTaskStage) {
    HJTaskStageCancelled = 0,
    HJTaskStageFinished  = 1, /// (succeed or failed).
};

typedef NSString * _Nullable HJTaskKey;
static const HJTaskKey HJTaskKeyInvalid = nil;

static inline HJTaskKey HJCreateTaskKey(NSString *identifier) {
    if (identifier == nil || [identifier length] <= 0) return HJTaskKeyInvalid;;
    
    const char *value = [identifier UTF8String];
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *key = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [key appendFormat:@"%02x", outputBuffer[count]];
    }
    return key;
}

/// size in bytes, expectedSize(-1 means unknown)
typedef void (^HJTaskProgressBlock)(HJTaskKey key, NSProgress * _Nullable taskProgress);

typedef void (^HJTaskCompletionBlock)(HJTaskKey key,
                                      HJTaskStage stage,
                                      NSDictionary<NSString *, id> *_Nullable callbackInfo,
                                      NSError *_Nullable error);

NS_ASSUME_NONNULL_BEGIN

@protocol HJTaskProtocol <NSObject>

@optional
@property (nonatomic, copy, nullable) HJTaskKey taskKey;
@property (nonatomic, copy, nullable) HJTaskProgressBlock taskProgress;
@property (nonatomic, copy, nullable) HJTaskCompletionBlock taskCompletion;
@property (nonatomic, assign) BOOL allowBackground; // default: YES

- (void)startTask;
- (void)cancelTask;

@end

NS_ASSUME_NONNULL_END
