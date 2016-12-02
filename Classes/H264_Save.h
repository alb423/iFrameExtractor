//
//  H264_Save.h
//  iFrameExtractor
//
//  Created by Liao KuoHsun on 13/5/24.
//
//

#ifndef H264_Save_h
#define H264_Save_h


// TODO: when PTS_DTS_IS_CORRECT==1, it should ok??
#define PTS_DTS_IS_CORRECT 0

extern int  h264_file_create(const char *pFilePath, AVFormatContext *fc, AVCodecContext *pCodecCtx,AVCodecContext *pAudioCodecCtx, double fps, void *p, int len );
extern void h264_file_write_frame(AVFormatContext *fc, int vStreamId, const void* p, int len, int64_t dts, int64_t pts);
extern void h264_file_write_audio_frame(AVFormatContext *fc, AVCodecContext  *pAudioCodecContext,int vStreamIdx, const void* p, int len, int64_t dts, int64_t pts );
extern void h264_file_close(AVFormatContext *fc);

extern void h264_file_write_frame2(AVFormatContext *fc, int vStreamIdx, AVPacket *pkt );

typedef enum
{
    eH264RecIdle = 0,
    eH264RecInit,
    eH264RecActive,
    eH264RecClose
} eH264RecordState;


#endif
