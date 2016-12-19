//
//  Video.m
//  iFrameExtractor
//
//  Created by lajos on 1/10/10.
//  Copyright 2010 www.codza.com. All rights reserved.
//

#import "VideoFrameExtractor.h"
#import "Utilities.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface VideoFrameExtractor (private)
-(void)convertFrameToRGB;
-(UIImage *)imageFromAVFrame:(AVFrame *)pFrame width:(int)width height:(int)height;
-(void)saveFrame:(AVFrame *)pFrame width:(int)width height:(int)height index:(int)iFrame;
-(void)setupScaler;
@end

@implementation VideoFrameExtractor

#define RECORDING_AT_RTSP_START 0
//#define RECORDING_AT_RTSP_START 1

@synthesize outputWidth, outputHeight;

@synthesize bSnapShot, veVideoRecordState, RecordingTimer;


- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSLog(@"Snapshot save may fail...");
}

-(void)setOutputWidth:(int)newValue {
	if (outputWidth == newValue) return;
	outputWidth = newValue;
	[self setupScaler];
}

-(void)setOutputHeight:(int)newValue {
	if (outputHeight == newValue) return;
	outputHeight = newValue;
	[self setupScaler];
}


-(UIImage *)currentImage {
	if (!pYUVFrame->data[0]) return nil;
	[self convertFrameToRGB];
    
    // Save the image and clear the bSnapShot flag
    if(self.bSnapShot==YES)
    {
        UIImage *myimg=nil;
        
        struct SwsContext *pTempImgConvertCtx;
        
        AVFrame *pTmpAVFrame = av_frame_alloc();
        av_frame_unref(pTmpAVFrame);

        int bytes_num = av_image_get_buffer_size(AV_PIX_FMT_RGB24, pYUVFrame->width, pYUVFrame->height, 1);
        uint8_t* buff = (uint8_t*)av_malloc(bytes_num);
        av_image_fill_arrays((unsigned char **)(AVFrame *)pTmpAVFrame->data, pTmpAVFrame->linesize, buff, AV_PIX_FMT_RGB24, pYUVFrame->width, pYUVFrame->height, 1);
        pTmpAVFrame->width = outputWidth;
        pTmpAVFrame->height = outputHeight;
        pTmpAVFrame->format = AV_PIX_FMT_RGB24;
        
        pTempImgConvertCtx = sws_getContext(pCodecCtx->width,
                                            pCodecCtx->height,
                                            pCodecCtx->pix_fmt,
                                            pYUVFrame->width,
                                            pYUVFrame->height,
                                            AV_PIX_FMT_RGB24,
                                            SWS_FAST_BILINEAR,
                                             NULL,
                                             NULL,
                                             NULL);
     
        sws_scale (pTempImgConvertCtx, (const uint8_t **)pYUVFrame->data, pYUVFrame->linesize,
                   0, pCodecCtx->height,
                   pTmpAVFrame->data, pTmpAVFrame->linesize);
        
        myimg = [self imageFromAVFrame:pTmpAVFrame width:pYUVFrame->width height:pYUVFrame->height];

        
            UIImageWriteToSavedPhotosAlbum(myimg, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
            self.bSnapShot = NO;
        
            return myimg;
        
    }
    
	return [self imageFromAVFrame:pRGBFrame width:outputWidth height:outputHeight];
}

-(double)duration {
	return (double)pFormatCtx->duration / AV_TIME_BASE;
}

-(double)currentTime {
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}

-(int)sourceWidth {
	return pCodecCtx->width;
}

-(int)sourceHeight {
	return pCodecCtx->height;
}

-(id)initWithVideo:(NSString *)moviePath {
	if (!(self=[super init])) return nil;
 
    AVCodec         *pCodec, *pAudioCodec;
		
    // Register all formats and codecs
    avcodec_register_all();
    av_register_all();
    
	avformat_network_init();
    
    // Open video file
    AVDictionary *opts = 0;
    av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    
    if(avformat_open_input(&pFormatCtx, [moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, &opts) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
	av_dict_free(&opts);
    
    // Retrieve stream information
    if(avformat_find_stream_info(pFormatCtx,NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    // Find the first video stream
    if ((videoStream =  av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        goto initError;
    }
    
    // Get a pointer to the codec context for the video stream
    pCodecCtx = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(pCodecCtx, pFormatCtx->streams[videoStream]->codecpar);
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        goto initError;
    }
	
    // Open codec
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        goto initError;
    }
	
    if ((audioStream =  av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &pAudioCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
    }
    else
    {
        pAudioCodecCtx = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(pAudioCodecCtx, pFormatCtx->streams[audioStream]->codecpar);
        
        // Find the decoder for the audio stream
        pAudioCodec = avcodec_find_decoder(pAudioCodecCtx->codec_id);
        if(pAudioCodec == NULL) {
            av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
            goto initError;
        }
        
        // Open codec
        if(avcodec_open2(pAudioCodecCtx, pAudioCodec, NULL) < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot open audio decoder\n");
            goto initError;
        }

    }
    
    av_dump_format(pFormatCtx, 0, [moviePath cStringUsingEncoding:NSASCIIStringEncoding], 0);
    
	outputWidth = pCodecCtx->width;
	outputHeight = pCodecCtx->height;
		
    // Allocate video frame
    pYUVFrame = av_frame_alloc();
    int bytes_num = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, outputWidth, outputHeight, 1);
    uint8_t* buff = (uint8_t*)av_malloc(bytes_num);
    av_image_fill_arrays((unsigned char **)(AVFrame *)pYUVFrame->data, pYUVFrame->linesize, buff, AV_PIX_FMT_YUV420P, outputWidth, outputHeight, 1);
    pYUVFrame->width = outputWidth;
    pYUVFrame->height = outputHeight;
    pYUVFrame->format = AV_PIX_FMT_YUV420P;
    
	return self;
	
initError:
	[self release];
	return nil;
}


-(void)setupScaler {

	// Release old RGB frame and scaler
	av_free(pRGBFrame);
	sws_freeContext(pImgConvertCtx);
	
	// Allocate RGB frame
    pRGBFrame = av_frame_alloc();
    av_frame_unref(pRGBFrame);
    
    int bytes_num = av_image_get_buffer_size(AV_PIX_FMT_RGB24, pYUVFrame->width, pYUVFrame->height, 1);
    uint8_t* buff = (uint8_t*)av_malloc(bytes_num);
    av_image_fill_arrays((unsigned char **)(AVFrame *)pRGBFrame->data, pRGBFrame->linesize, buff, AV_PIX_FMT_RGB24, pYUVFrame->width, pYUVFrame->height, 1);
    pRGBFrame->width = outputWidth;
    pRGBFrame->height = outputHeight;
    pRGBFrame->format = AV_PIX_FMT_RGB24;
    
	// Setup scaler
	static int sws_flags =  SWS_FAST_BILINEAR;
	pImgConvertCtx = sws_getContext(pCodecCtx->width,
									 pCodecCtx->height,
									 pCodecCtx->pix_fmt,
									 outputWidth, 
									 outputHeight,
									 AV_PIX_FMT_RGB24,
									 sws_flags, NULL, NULL, NULL);
	
}

-(void)seekTime:(double)seconds {
	AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
	int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
	avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
	avcodec_flush_buffers(pCodecCtx);
}

-(void)dealloc {
    
    [aPlayer Stop:TRUE];
    
	// Free scaler
	sws_freeContext(pImgConvertCtx);

	// Free RGB frame
    av_free(pRGBFrame);
    
    // Free the packet that was allocated by av_read_frame
    av_packet_unref(&packet);
	
    // Free the YUV frame
    av_free(pYUVFrame);
	
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
	
    // Close the video file
    if (pFormatCtx) avformat_close_input(&pFormatCtx);
	
	[super dealloc];
}

-(void)StopRecording:(NSTimer *)timer {
    veVideoRecordState = eH264RecClose;
    NSLog(@"eH264RecClose");
    [timer invalidate];
}

-(BOOL)stepFrame {
    int frameFinished=0;
    static bool bFirstIFrame=false;
    static int64_t vPTS=0, vDTS=0, vAudioPTS=0, vAudioDTS=0;
    
    while(!frameFinished && av_read_frame(pFormatCtx, &packet)>=0) {
        // Is this a packet from the video stream?
        int vRet = 0;
        if(packet.stream_index==videoStream) {
            
            
            // Initialize a new format context for writing file
            if(veVideoRecordState!=eH264RecIdle)
            {
                switch(veVideoRecordState)
                {
                    case eH264RecInit:
                    {                        
                        if ( !pFormatCtx_Record )
                        {
                            int bFlag = 0;
                            //NSString *videoPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/test.mp4"];
                            NSString *videoPath = @"/Users/liaokuohsun/iFrameTest.mp4";
                            
                            const char *file = [videoPath UTF8String];
                            //pFormatCtx_Record = avformat_alloc_context();
                            avformat_alloc_output_context2(&pFormatCtx_Record, NULL, NULL, file);
                            bFlag = h264_file_create(file, pFormatCtx_Record, pCodecCtx, pAudioCodecCtx,/*fps*/0.0, packet.data, packet.size );
                            
                            if(bFlag==true)
                            {
                                veVideoRecordState = eH264RecActive;
                                fprintf(stderr, "h264_file_create success\n");                                
                            }
                            else
                            {
                                veVideoRecordState = eH264RecIdle;
                                fprintf(stderr, "h264_file_create error\n");
                            }
                        }
                    }
                    //break;
                        
                    case eH264RecActive:
                    {
                        if((bFirstIFrame==false) &&(packet.flags&AV_PKT_FLAG_KEY)==AV_PKT_FLAG_KEY)
                        {
                            bFirstIFrame=true;
                            vPTS = packet.pts ;
                            vDTS = packet.dts ;
#if 0
                            NSRunLoop *pRunLoop = [NSRunLoop currentRunLoop];
                            [pRunLoop addTimer:RecordingTimer forMode:NSDefaultRunLoopMode];
#else
                            [NSTimer scheduledTimerWithTimeInterval:5.0//2.0
                                                             target:self
                                                           selector:@selector(StopRecording:)
                                                           userInfo:nil
                                                            repeats:NO];
#endif
                        }
                        
                        // Record audio when 1st i-Frame is obtained
                        if(bFirstIFrame==true)
                        {
                            if ( pFormatCtx_Record )
                            {
#if PTS_DTS_IS_CORRECT==1
                                packet.pts = packet.pts - vPTS;
                                packet.dts = packet.dts - vDTS;
                                                                                       
#endif
//                                h264_file_write_frame2( pFormatCtx_Record, packet.stream_index, &packet);
                                    h264_file_write_frame( pFormatCtx_Record, packet.stream_index, packet.data, packet.size, packet.dts, packet.pts);

                            }
                            else
                            {
                                NSLog(@"pFormatCtx_Record no exist");
                            }
                        }
                    }
                    break;
                        
                    case eH264RecClose:
                    {
                        bFirstIFrame = false;
                        veVideoRecordState = eH264RecIdle;
                        
                        if ( pFormatCtx_Record )
                        {
                            h264_file_close(pFormatCtx_Record);
#if 0
                            // 20130607 Test, TODO: remove me
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
                            {
                                ALAssetsLibrary *library = [[ALAssetsLibrary alloc]init];
                                NSString *filePathString = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/test.mp4"];
                                NSURL *filePathURL = [NSURL fileURLWithPath:filePathString isDirectory:NO];
                                if(1)// ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:filePathURL])
                                {
                                    [library writeVideoAtPathToSavedPhotosAlbum:filePathURL completionBlock:^(NSURL *assetURL, NSError *error){
                                        if (error) {
                                            // TODO: error handling
                                            NSLog(@"writeVideoAtPathToSavedPhotosAlbum error");
                                        } else {
                                            // TODO: success handling
                                            NSLog(@"writeVideoAtPathToSavedPhotosAlbum success");
                                        }
                                    }];
                                }
                                [library release];
                            });
#endif
                            vPTS = 0;
                            vDTS = 0;
                            vAudioPTS = 0;
                            vAudioDTS = 0;
                            pFormatCtx_Record = NULL;
                            NSLog(@"h264_file_close() is finished");
                        }
                        else
                        {
                            NSLog(@"fc no exist");
                        }
                    }
                    break;
                        
                    default:
                        if ( pFormatCtx_Record )
                        {
                            h264_file_close(pFormatCtx_Record);
                            pFormatCtx_Record = NULL;
                        }
                        NSLog(@"[ERROR] unexpected veVideoRecordState!!");
                        veVideoRecordState = eH264RecIdle;
                        break;
                }
            }
            
            // Decode video frame
            avcodec_send_packet(pCodecCtx, &packet);
            do {
                vRet = avcodec_receive_frame(pCodecCtx, pYUVFrame);
            } while(vRet==EAGAIN);
            
            if(vRet==0) frameFinished=1;
            else frameFinished=0;

        }
        else if(packet.stream_index==audioStream)
        {
            static int vPktCount=0;
            BOOL bIsAACADTS = FALSE;

            if(aPlayer.vAACType == eAAC_UNDEFINED)
            {
                tAACADTSHeaderInfo vxAACADTSHeaderInfo = {0};
                bIsAACADTS = [AudioUtilities parseAACADTSHeader:(uint8_t *)packet.data ToHeader:&vxAACADTSHeaderInfo];
            }
            
            @synchronized(aPlayer)
            {
                if(aPlayer==nil)
                {
                    aPlayer = [[AudioPlayer alloc]initAudio:nil withCodecCtx:(AVCodecContext *) pAudioCodecCtx];
                    NSLog(@"aPlayer initAudio");
                    
                    if(bIsAACADTS)
                    {
                        aPlayer.vAACType = eAAC_ADTS;
                        NSLog(@"is ADTS AAC");
                    }
                }
                else
                {
                    if(vPktCount<5) // The voice is listened once image is rendered
                    {
                        vPktCount++;
                    }
                    else
                    {
                        if([aPlayer getStatus]!=eAudioRunning)
                        {
                            NSLog(@"aPlayer start play");
                            [aPlayer Play];
                        }
                    }
                }
            };
            
            @synchronized(aPlayer)
            {
                int ret = 0;
                
//                    AVPacket vxPacket = {0};
//                    uint8_t *pTmp = (uint8_t *) malloc(frameDataLength);
//                    memcpy(pTmp, frameData, frameDataLength);
//                    vxPacket.data = (uint8_t *)pTmp;
//                    vxPacket.size = frameDataLength;
//                    ret = [aPlayer putAVPacket:&vxPacket];
                
                ret = [aPlayer putAVPacket:&packet];
                if(ret <= 0)
                    NSLog(@"Put Audio Packet Error!!");
                
            }
        
            if(bFirstIFrame==true)
            {
                switch(veVideoRecordState)
                {
                    case eH264RecActive:
                    {
                        if ( pFormatCtx_Record )
                        {
                            h264_file_write_audio_frame(pFormatCtx_Record, pAudioCodecCtx, packet.stream_index, packet.data, packet.size, packet.dts, packet.pts);
                            
                        }
                        else
                        {
                            NSLog(@"pFormatCtx_Record no exist");
                        }
                    }
                }
            }
        }
        else
        {
            //fprintf(stderr, "packet len=%d, Byte=%02X%02X%02X%02X%02X\n",\
                    packet.size, packet.data[0],packet.data[1],packet.data[2],packet.data[3], packet.data[4]);
        }
    }
	return frameFinished!=0;
}

-(void)convertFrameToRGB {	
	sws_scale (pImgConvertCtx, (const uint8_t **)pYUVFrame->data, pYUVFrame->linesize,
			   0, pCodecCtx->height,
			   pRGBFrame->data, pRGBFrame->linesize);
}

-(UIImage *)imageFromAVFrame:(AVFrame *)frame width:(int)width height:(int)height {
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, frame->data[0], frame->linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       frame->linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

-(void)savePPMPicture:(AVFrame *)frame width:(int)width height:(int)height index:(int)iFrame {
    FILE *pFile;
	NSString *fileName;
    int  y;
	
	fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if(pFile==NULL)
        return;
	
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
	
    // Write pixel data
    for(y=0; y<height; y++)
        fwrite(frame->data[0]+y*frame->linesize[0], 1, width*3, pFile);
	
    // Close file
    fclose(pFile);
}

@end
