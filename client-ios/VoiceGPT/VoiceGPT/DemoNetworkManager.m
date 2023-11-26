//
//  DemoNetworkManager.m
//  VoiceGPT
//
//  Created by wyh on 2023/11/13.
//


#import "DemoNetworkManager.h"
#import <AVFoundation/AVFoundation.h>

static NSString * DemoURLAppend(NSString *str) {
    NSString *netIP = @"http://43.128.104.107";
    NSString *port = @"5005";
    NSString *flaskHost = [NSString stringWithFormat:@"%@:%@",netIP, port];
    return [flaskHost stringByAppendingString:str];
}


static NSString * DemoGenerateUserID(void) {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: 6];

    for (NSInteger i = 0; i < 6; i++) {
         [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((uint32_t)[letters length])]];
    }

    return randomString;
}

@implementation DemoNetworkHTTPAudioSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError * _Nullable __autoreleasing *)error {
    if ([[response MIMEType] isEqualToString:@"audio/mpeg"]) {
        NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *localFilePath = [documents stringByAppendingPathComponent:@"speech.mp3"];
        [data writeToFile:localFilePath atomically:YES];
        return localFilePath;
    }
    
    return [super responseObjectForResponse:response data:data error:error];
}

- (NSSet<NSString *> *)acceptableContentTypes {
    return [NSSet setWithObjects:
            @"text/javascript",
            @"application/json",
            @"text/json",
            @"audio/mpeg",
            nil];
}

@end

@interface DemoNetworkManager ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;

@property (nonatomic, copy) NSString *userId;

@end

@implementation DemoNetworkManager

+ (instancetype)sharedManager {
    
    static DemoNetworkManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[[DemoNetworkManager alloc] init] initialize];
    });
    return manager;
}

- (instancetype)initialize {
    
    _sessionManager = AFHTTPSessionManager.manager;
    
    _userId = [NSString stringWithFormat:@"%@", DemoGenerateUserID()];
    NSLog(@"当前用户id：%@",_userId);    
    
    DemoNetworkHTTPAudioSerialization *responseSerializer = [DemoNetworkHTTPAudioSerialization serializer];
    responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"audio/mpeg"];
    _sessionManager.responseSerializer = responseSerializer;
    
    AFHTTPRequestSerializer *requestSerializer = [AFHTTPRequestSerializer serializer];
    requestSerializer.timeoutInterval = 60;
    _sessionManager.requestSerializer = requestSerializer;
        
    return self;
}

- (void)test {
    [_sessionManager POST:DemoURLAppend(@"/chatgpt")
               parameters:@{ @"content": @"你好，请问2020年世界杯谁获胜了？" }
                  headers:nil
                 progress:^(NSProgress * _Nonnull downloadProgress) {
        
    }
                               
                  success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"success:%@",responseObject);
    }
                  failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"failed:%@",error);
    }];
}

- (void)requestVoiceChatWithInputAudioFilePath:(NSString *)filePath
                                    completion:(void(^)(BOOL isSuccess, NSString *speechLocalFilePath))completion {
    
    NSString *fileName = [filePath pathComponents].lastObject;
        
    void (^constructingBlock)(id<AFMultipartFormData> formData) = ^(id<AFMultipartFormData> formData) {
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        NSError *error;
        [formData appendPartWithFileURL:fileUrl name:@"file" fileName:fileName mimeType:@"audio/mp3" error:&error];
        if (error) {
            NSLog(@"Error appending part: %@", error);
        }
    };
    
    
    [_sessionManager POST:DemoURLAppend(@"/voiceChat")
               parameters:nil
                  headers:@{ @"userId": _userId }
constructingBodyWithBlock:constructingBlock
                 progress:^(NSProgress * _Nonnull uploadProgress) {
        
        NSLog(@"Upload Progress: %.2f%%", uploadProgress.fractionCompleted * 100);
        
    } success:^(NSURLSessionDataTask * _Nonnull task, NSString *speechLocalFilePath) {
        
        if (completion) {
            completion(speechLocalFilePath > 0, speechLocalFilePath);
        }
        NSLog(@"Local Speech Path: %@", speechLocalFilePath);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        if (completion) {
            completion(NO, nil);
        }
        
        NSLog(@"Error: %@", error);
        
    }];
}


@end
