//
//  iFrameExtractorViewController.m
//  iFrameExtractor
//
//  Created by Liao KuoHsun on 2016/11/24.
//
//

#import "iFrameExtractorViewController.h"

#import "VideoFrameExtractor.h"
#import "Utilities.h"
#include "H264_Save.h"

@interface iFrameExtractorViewController ()

@end

@implementation iFrameExtractorViewController
@synthesize imageView, label, playButton, video, RecordProgressLevel, vRecordSeconds;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Test URL
    // rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov
    // http://210.65.250.18:8080/cam000b67014ff5001/20131023/090000.mp4

    // Test File
    // 7h800-2.mp4
    // h265_ex3.mp4
    
    
    NSLog(@"Try Connect: %f",video.duration);
    //video = [[VideoFrameExtractor alloc] initWithVideo:[Utilities bundlePath:@"7h800-2.mp4"]];
    video = [[VideoFrameExtractor alloc] initWithVideo:[Utilities bundlePath:@"h265_ex3.mp4"]];
    //video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://192.168.11.2:8554/h265ESVideoTest"];
    //video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://172.19.19.146/stream1"];
    
    // set output image size
    video.outputWidth = 1280-120; // reserver 120 pixel for control button
    video.outputHeight = 720;
    
    // print some info about the video
    NSLog(@"video duration: %f",video.duration);
    NSLog(@"video size: %d x %d", video.sourceWidth, video.sourceHeight);
    
    // set the initial value to progress level
    [RecordProgressLevel setHidden:YES];
    
    // If video images are landscape, so rotate image view 90 degrees
    //[imageView setTransform:CGAffineTransformMakeRotation(M_PI/2)];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#if RECORDING_AT_RTSP_START==1
-(void)StopRecording:(NSTimer *)timer {
    video.veVideoRecordState = eH264RecClose;
    NSLog(@"eH264RecClose");
    [timer invalidate];
}
#endif

-(IBAction)playButtonAction:(id)sender {
    [playButton setEnabled:NO];
    lastFrameTime = -1;
    
    // seek to 0.0 seconds
    [video seekTime:0.0];
    
    
#if RECORDING_AT_RTSP_START==1
    video.veVideoRecordState = eH264RecInit;
    [NSTimer scheduledTimerWithTimeInterval:10.0
                                     target:self
                                   selector:@selector(StopRecording:)
                                   userInfo:nil
                                    repeats:NO];
#endif
    
    [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                     target:self
                                   selector:@selector(displayNextFrame:)
                                   userInfo:nil
                                    repeats:YES];
}


- (IBAction)SnapShotButtonAction:(id)sender {
    video.bSnapShot = YES;
}


#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

-(void)displayNextFrame:(NSTimer *)timer {
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    if (![video stepFrame]) {
        [timer invalidate];
        [playButton setEnabled:YES];
        return;
    }
    imageView.image = video.currentImage;
    float frameTime = 1.0/([NSDate timeIntervalSinceReferenceDate]-startTime);
    if (lastFrameTime<0) {
        lastFrameTime = frameTime;
    } else {
        lastFrameTime = LERP(frameTime, lastFrameTime, 0.8);
    }
    [label setText:[NSString stringWithFormat:@"%.0f",lastFrameTime]];
}


#pragma mark - ffmpeg usage
-(void)UpdateProgressLevel:(NSTimer *)timer {
    NSLog(@"RecordProgress:%d", vRecordSeconds);
    
    if(vRecordSeconds==0)
    {
        video.veVideoRecordState = eH264RecClose;
        [RecordProgressLevel setHidden:YES];
        [timer invalidate];
    }
    else
    {
        vRecordSeconds--;
    }
    NSString *vpTmp = [NSString stringWithFormat:@"Recording 00:%02d", vRecordSeconds];
    [RecordProgressLevel setText:vpTmp];
    
}

- (IBAction)RecordButtionAction:(id)sender {
    video.veVideoRecordState = eH264RecInit;
    
    // Update the recording progress
    vRecordSeconds = RECPRDING_SECONDS;
    NSString *vpTmp = [NSString stringWithFormat:@"Recording 00:%02d", vRecordSeconds];
    [RecordProgressLevel setText:vpTmp];
    
    [RecordProgressLevel setHidden:NO];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(UpdateProgressLevel:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)dealloc {
    [super dealloc];
}
@end
