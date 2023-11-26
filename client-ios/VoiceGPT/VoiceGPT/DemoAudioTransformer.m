//
//  DemoAudioTransformer.m
//  VoiceGPT
//
//  Created by wyh on 2023/11/19.
//

#import "DemoAudioTransformer.h"
#import "lame.h"

@implementation DemoAudioTransformer


+ (void)convenrtCAF2MP3WithCAFPath:(NSString *)originalPath
                           mp3Path:(NSString *)mp3Path
                           success:(void(^)(BOOL isSuccess))successBlockHandler {
    
    [[NSFileManager defaultManager] removeItemAtPath:mp3Path error:nil];
  
    @try {
        int read, write;
        
        FILE *pcm = fopen([originalPath cStringUsingEncoding:1], "rb");//被转换的文件
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([mp3Path cStringUsingEncoding:1], "wb");//转换后文件的存放位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_num_channels (lame, 2 ); // 设置 1 为单通道，默认为 2 双通道
        lame_set_in_samplerate(lame, 44100);//
        lame_set_brate (lame, 8);
        lame_set_mode (lame, 3);
        lame_set_VBR(lame, vbr_default);
        lame_set_quality (lame, 2); /* 2=high  5 = medium  7=low 音 质 */
        lame_init_params(lame);
        
        do {
            read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        // NSLog(@"%@",[exception description]);
        if (successBlockHandler) successBlockHandler(NO);
    }
    @finally {
        if (successBlockHandler) successBlockHandler(YES);
    }
}

@end
