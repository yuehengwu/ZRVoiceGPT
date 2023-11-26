//
//  DemoNetworkManager.h
//  VoiceGPT
//
//  Created by wyh on 2023/11/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DemoNetworkHTTPAudioSerialization : AFHTTPResponseSerializer



@end

@interface DemoNetworkManager : NSObject

+ (instancetype)sharedManager;

- (void)test;

- (void)requestVoiceChatWithInputAudioFilePath:(NSString *)filePath
                                    completion:(void(^)(BOOL isSuccess, NSString *speechLocalFilePath))completion;

@end

NS_ASSUME_NONNULL_END
