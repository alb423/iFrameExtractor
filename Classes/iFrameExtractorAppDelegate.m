//
//  iFrameExtractorAppDelegate.m
//  iFrameExtractor
//
//  Created by lajos on 1/8/10.
//
//  Copyright 2010 Lajos Kamocsay
//
//  lajos at codza dot com
//
//  iFrameExtractor is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
// 
//  iFrameExtractor is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//

#import "iFrameExtractorAppDelegate.h"
#import "VideoFrameExtractor.h"
#import "Utilities.h"

// 20130525 albert.liao modified start
#include "H264_Save.h"
// 20130525 albert.liao modified end


@implementation iFrameExtractorAppDelegate

@synthesize window, imageView, label, playButton, video, RecordProgressLevel, vRecordSeconds;

- (void)dealloc {
	[video release];
	[imageView release];
	[label release];
	[playButton release];
    [window release];
    [_RecordButton release];
    [_SnapShotButton release];
    [RecordProgressLevel release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {

    // 20130524 albert.liao modified start
    // The test file url is http://http://mm2.pcslab.com/mm/
//    self.video = [[VideoFrameExtractor alloc] initWithVideo:[Utilities bundlePath:@"7h800-2.mp4"]];
	//self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://mm2.pcslab.com/mm/7h800.mp4"];
    //self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://192.168.82.75/stream2"];
    //self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://192.168.82.81/stream2"];
//    self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://mm2.pcslab.com/mm/7h1500.mp4"];
    
    //self.video = [[VideoFrameExtractor alloc] initWithVideo:@"http://210.65.250.18:8080/cam000b67014ff5001/20131023/090000.mp4"];
    self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov"];
    
    // 20130524 albert.liao modified end
    //[video release];

	// set output image size
	video.outputWidth = 240;
	video.outputHeight = 160;
	
	// print some info about the video
	NSLog(@"video duration: %f",video.duration);
	NSLog(@"video size: %d x %d", video.sourceWidth, video.sourceHeight);
	
    // set the initial value to progress level
    [RecordProgressLevel setHidden:YES];
    
	// video images are landscape, so rotate image view 90 degrees
	[imageView setTransform:CGAffineTransformMakeRotation(M_PI/2)];
    //[window makeKeyAndVisible];
}

#if RECORDING_AT_RTSP_START==1
-(void)StopRecording:(NSTimer *)timer {
    self.video.veVideoRecordState = eH264RecClose;
    NSLog(@"eH264RecClose");
    [timer invalidate];
}
#endif

-(IBAction)playButtonAction:(id)sender {
	[playButton setEnabled:NO];
	lastFrameTime = -1;
	
	// seek to 0.0 seconds
	[video seekTime:0.0];

    // 20130529 temprary test start

#if RECORDING_AT_RTSP_START==1
    self.video.veVideoRecordState = eH264RecInit;
	[NSTimer scheduledTimerWithTimeInterval:10.0
									 target:self
								   selector:@selector(StopRecording:)
								   userInfo:nil
									repeats:NO];
#endif
    // 20130529 temprary test end
    
	[NSTimer scheduledTimerWithTimeInterval:1.0/30
									 target:self
								   selector:@selector(displayNextFrame:)
								   userInfo:nil
									repeats:YES];
}

- (IBAction)showTime:(id)sender {
    NSLog(@"current time: %f s",video.currentTime);
}

// 20130524 albert.liao modified start
- (IBAction)SnapShotButtonAction:(id)sender {
    self.video.bSnapShot = YES;
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
        self.video.veVideoRecordState = eH264RecClose;
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
    self.video.veVideoRecordState = eH264RecInit;
    
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
// 20130524 albert.liao modified end


@end
