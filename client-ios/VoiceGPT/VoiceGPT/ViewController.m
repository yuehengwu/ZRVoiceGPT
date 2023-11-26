//
//  ViewController.m
//  VoiceGPT
//
//  Created by wyh on 2023/11/11.
//

#import "ViewController.h"
#import "DemoNetworkManager.h"
#import "DemoAudioTransformer.h"
#import "DemoWaveRecordView.h"
#import <Masonry/Masonry.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger, DemoUIState) {
    DemoUIStateNormal,
    DemoUIStateUserSpeak,
    DemoUIStateFetchGPT,
    DemoUIStateGPTSpeak,
};

@interface ViewController () <AVAudioPlayerDelegate>

@property (nonatomic, assign) BOOL selected;

@property (nonatomic, strong) UIImageView *logoView;

@property (nonatomic, strong) UILabel *textLabel;

;@property (nonatomic, strong) DemoWaveRecordView *waveRecordView;

@property (strong, nonatomic) AVAudioRecorder *audioRecorder;

@property (strong, nonatomic) NSString *audioFilePath;

@property (nonatomic, strong) AVAudioPlayer *speakPlayer;

@property (nonatomic, strong) UIActivityIndicatorView *loadingView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initialize];
    
    [self configUI];
                
}

#pragma mark - Initialize

- (void)initialize {
    // voice audio
    
    _audioFilePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"audio_file.caf"];
    
    _audioRecorder = ({
        
        NSURL *outputFileURL = [NSURL fileURLWithPath:_audioFilePath];
                        
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        
        NSDictionary *recordSetting = @{AVEncoderAudioQualityKey: @(AVAudioQualityMin),
                                        AVEncoderBitRateKey: @16,
                                        AVNumberOfChannelsKey: @2,
                                        AVSampleRateKey: @44100.0};
                
        NSError *error;
        AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:&error];
        if (error) {
            NSLog(@"初始化录音器时出错: %@", [error localizedDescription]);
        } else {
            [recorder prepareToRecord];
        }
        recorder;
    });
}

#pragma mark - Methods

- (void)tapAction:(id)sender {
    _selected = !_selected;
    if (_selected) {
        [self tapToSpeak];
    }else {
        [self tapToEnd];
    }
}


- (void)tapToSpeak {
    [self ui_changeInto:(DemoUIStateUserSpeak)];
    
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    if (!self.audioRecorder.recording) {
        [AVAudioSession.sharedInstance setActive:YES error:nil];
        [self.audioRecorder record];
    }
}


- (void)tapToEnd {
    [self ui_changeInto:(DemoUIStateFetchGPT)];
    
    if (self.audioRecorder.recording) {
        [self.audioRecorder stop];
        [AVAudioSession.sharedInstance setActive:NO error:nil];
        // convert caf to mp3
        NSString *mp3FilePath = [self convertToMP3FilePath:_audioFilePath];
        [DemoAudioTransformer convenrtCAF2MP3WithCAFPath:_audioFilePath
                                                 mp3Path:mp3FilePath
                                                 success:^(BOOL isSuccess) {
            
            if (isSuccess) {
                // request STT
                [DemoNetworkManager.sharedManager requestVoiceChatWithInputAudioFilePath:mp3FilePath
                                                                              completion:^(BOOL isSuccess,
                                                                                           NSString * _Nonnull speechLocalFilePath) {
                    if (isSuccess) {
                        [self speakAudioWithFilePath:speechLocalFilePath];
                    }else {
                        [self ui_changeInto:(DemoUIStateNormal)];
                    }
                    
                }];
            }else {
                [self ui_changeInto:(DemoUIStateNormal)];
            }
        }];
    }
}

- (void)speakAudioWithFilePath:(NSString *)filePath {
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:nil];
    NSError *error;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:&error];
    player.delegate = self;
    if (error) {
        NSLog(@"初始化播放器失败:%@",error.localizedDescription);
    }
    if (!player.isPlaying) {
        [player play];
        [self ui_changeInto:(DemoUIStateGPTSpeak)];
    }
    _speakPlayer = player;
}

- (NSString *)convertToMP3FilePath:(NSString *)cafFilePath {
    NSString *mp3FilePath = [[cafFilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp3"];
    NSLog(@"当前音频mp3文件路径:%@",mp3FilePath);
    return mp3FilePath;
}

#pragma mark - Delegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self ui_changeInto:(DemoUIStateNormal)];
}

#pragma mark - UI

- (void)ui_changeInto:(DemoUIState)uiState {
    switch (uiState) {
        case DemoUIStateNormal: {
            self.view.userInteractionEnabled = YES;
            [_waveRecordView stopAnimating];
            [_loadingView stopAnimating];
            _textLabel.attributedText = ({
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"Tap to Speak"];
                [attrStr setAttributes:@{
                    NSForegroundColorAttributeName: UIColor.systemGreenColor
                }
                                 range:NSMakeRange(7, 5)];
                attrStr;
            });
            
        }
            break;
        case DemoUIStateUserSpeak: {
            self.view.userInteractionEnabled = YES;
            [_waveRecordView startAnimating];
            [_loadingView stopAnimating];
            _textLabel.attributedText = ({
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"Tap to End"];
                [attrStr setAttributes:@{
                    NSForegroundColorAttributeName: UIColor.systemRedColor
                }
                                 range:NSMakeRange(7, 3)];
                attrStr;
            });
        }
            break;
        case DemoUIStateFetchGPT: {
            self.view.userInteractionEnabled = NO;
            [_waveRecordView stopAnimating];
            [_loadingView startAnimating];
            _textLabel.attributedText = ({
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"Wait for GPT.."];
                NSRange range = [attrStr.string rangeOfString:@"GPT"];
                [attrStr setAttributes:@{
                    NSForegroundColorAttributeName: UIColor.systemYellowColor
                }
                                 range:NSMakeRange(range.location, range.length)];
                attrStr;
            });
        }
            break;
        case DemoUIStateGPTSpeak: {
            self.view.userInteractionEnabled = NO;
            [_waveRecordView startAnimating];
            [_loadingView stopAnimating];
            _textLabel.attributedText = ({
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"GPT Speaking.."];
                [attrStr setAttributes:@{
                    NSForegroundColorAttributeName: UIColor.systemBlueColor
                }
                                 range:NSMakeRange(0, 3)];
                attrStr;
            });
        }
            break;
        default:
            break;
    }
}

- (void)configUI {
    self.view.backgroundColor = UIColor.whiteColor;
    
    _logoView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo.png"]];
        [self.view addSubview:imageView];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view.mas_top).offset(120);
            make.centerX.equalTo(self.view.mas_centerX);
            make.size.mas_equalTo(CGSizeMake(120, 120));
        }];
        imageView;
    });
    
    _textLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.textColor = UIColor.blackColor;
        label.attributedText = ({
            NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"Tap to Speak"];
            [attrStr setAttributes:@{
                NSForegroundColorAttributeName: UIColor.greenColor
            }
                             range:NSMakeRange(7, 5)];
            attrStr;
        });
        
        label.font = [UIFont systemFontOfSize:50];
        label.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:label];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.view);
            make.bottom.equalTo(self.view.mas_bottom).offset(-200);
        }];
        label.center = CGPointMake(self.view.center.x, label.center.y);
        label;
    });
    
    _waveRecordView = ({
        DemoWaveRecordView *waveView = [[DemoWaveRecordView alloc] init];
        waveView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) * 1/3);
        [self.view addSubview:waveView];
        waveView.center = self.view.center;
        waveView;
    });
    
    _loadingView = ({
        UIActivityIndicatorView *loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleLarge)];
//        loadingView.color = UIColor.whiteColor;
        loadingView.center = self.view.center;
        loadingView.transform = CGAffineTransformMakeScale(2, 2);
        [self.view addSubview:loadingView];
        loadingView;
    });
    
    UITapGestureRecognizer *tapGes = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self.view addGestureRecognizer:tapGes];
}

@end
