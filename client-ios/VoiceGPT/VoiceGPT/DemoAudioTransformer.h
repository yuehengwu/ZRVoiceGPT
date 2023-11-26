//
//  DemoAudioTransformer.h
//  VoiceGPT
//
//  Created by wyh on 2023/11/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DemoAudioTransformer : NSObject

+ (void)convenrtCAF2MP3WithCAFPath:(NSString *)originalPath
                           mp3Path:(NSString *)mp3Path
                           success:(void(^)(BOOL isSuccess))successBlockHandler;

@end

NS_ASSUME_NONNULL_END
