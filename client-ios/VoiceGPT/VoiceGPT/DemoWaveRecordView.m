//
//  DemoWaveRecordView.m
//  VoiceGPT
//
//  Created by wyh on 2023/11/19.
//

#import "DemoWaveRecordView.h"

@interface DemoWaveRecordView ()

@property (strong, nonatomic) CAShapeLayer *waveLayer;

@property (strong, nonatomic) CADisplayLink *displayLink;

@property (nonatomic) CGFloat phase;

@end

@implementation DemoWaveRecordView

- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化波浪线
        self.waveLayer = [CAShapeLayer layer];
        self.waveLayer.fillColor = [UIColor clearColor].CGColor;
        self.waveLayer.strokeColor = [UIColor blackColor].CGColor;
        self.waveLayer.lineWidth = 5.0;
        [self.layer addSublayer:self.waveLayer];
        
        // 初始化定时器
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateWave)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.displayLink.paused = YES;
    }
    return self;
}

- (void)startAnimating {
    self.displayLink.paused = NO;
    self.hidden = NO;
}

- (void)stopAnimating {
    self.displayLink.paused = YES;
    self.hidden = YES;
}

- (void)updateWave {
    self.phase += 7;
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat height = CGRectGetHeight(self.frame);
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    for (CGFloat x = 0.0; x < width; x += 1.0) {
        CGFloat y = sinf(0.01 * (self.phase + x)) * 10 + height / 2;
        if (x == 0.0) {
            [path moveToPoint:CGPointMake(x, y)];
        } else {
            [path addLineToPoint:CGPointMake(x, y)];
        }
    }
    
    self.waveLayer.path = path.CGPath;
}

@end
