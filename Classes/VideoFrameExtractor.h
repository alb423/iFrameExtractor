//
//  Video.h
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
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


#import <Foundation/Foundation.h>

#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

#include "H264_Save.h"

#import "AudioPlayer.h"
#import "AudioPacketQueue.h"
#import "AudioUtilities.h"

#define RECORDING_AT_RTSP_START 0
//#define RECORDING_AT_RTSP_START 1
#define RECPRDING_SECONDS 5

@interface VideoFrameExtractor : NSObject {
	AVFormatContext *pFormatCtx;
	AVCodecContext *pCodecCtx;
    
    AVFrame *pYUVFrame;
    AVFrame *pRGBFrame;
    AVPacket packet;
	int videoStream;
    int audioStream;
	struct SwsContext *pImgConvertCtx;
	int sourceWidth, sourceHeight;
	int outputWidth, outputHeight;
	UIImage *currentImage;
	double duration;
    double currentTime;
    
    AVFormatContext *pFormatCtx_Record;
    AVCodecContext *pAudioCodecCtx;
    
    AudioPlayer *aPlayer;
}

/* Last decoded picture as UIImage */
@property (nonatomic, readonly) UIImage *currentImage;

/* Size of video frame */
@property (nonatomic, readonly) int sourceWidth, sourceHeight;

/* Output image size. Set to the source size by default. */
@property (nonatomic) int outputWidth, outputHeight;

/* Length of video in seconds */
@property (nonatomic, readonly) double duration;

/* Current time of video in seconds */
@property (nonatomic, readonly) double currentTime;

/* Initialize with movie at moviePath. Output dimensions are set to source dimensions. */
-(id)initWithVideo:(NSString *)moviePath;

/* Read the next frame from the video stream. Returns false if no frame read (video over). */
-(BOOL)stepFrame;

/* Seek to closest keyframe near specified time */
-(void)seekTime:(double)seconds;

@property (nonatomic) BOOL bSnapShot;
@property (nonatomic) int veVideoRecordState;
@property (nonatomic, retain) NSTimer *RecordingTimer;              

@end
