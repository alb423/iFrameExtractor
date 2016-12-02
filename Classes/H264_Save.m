//
//  H264_Save.c
//  iFrameExtractor
//
//  Created by Liao KuoHsun on 13/5/24.
//
//

// Reference ffmpeg\doc\examples\muxing.c
#include <stdio.h>
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "H264_Save.h"
//#include "libavformat/avio.h"
#import "AudioUtilities.h"

int vVideoStreamIdx = -1, vAudioStreamIdx = -1,  waitkey = 1;



#if 1 //FFMpeg will link to libiconv(), so I write wrapp function here
#include <iconv.h>
size_t libiconv(iconv_t cd,
                char **inbuf, size_t *inbytesleft,
                char **outbuf, size_t *outbytesleft)
{
    return iconv( cd, inbuf, inbytesleft, outbuf, outbytesleft);
}

iconv_t libiconv_open(const char *tocode, const char *fromcode)
{
    return iconv_open(tocode, fromcode);
}

int libiconv_close(iconv_t cd)
{
    return iconv_close(cd);
}
#endif

// < 0 = error
// 0 = I-Frame
// 1 = P-Frame
// 2 = B-Frame
// 3 = S-Frame
static int getVopType( const void *p, int len )
{
    
    if ( !p || 6 >= len )
    {
        fprintf(stderr, "getVopType() error");
        return -1;
    }
    
    unsigned char *b = (unsigned char*)p;
    
    // Verify VOP id
    if ( 0xb6 == *b )
    {
        b++;
        return ( *b & 0xc0 ) >> 6;
    } // end if
    
    switch( *b )
    {
        case 0x65 : return 0;
        case 0x61 : return 1;
        case 0x01 : return 2;
    } // end switch
    
    return -1;
}

void h264_file_close(AVFormatContext *fc)
{
    if ( !fc )
        return;
    
    av_write_trailer( fc );
    
    if ( fc->oformat && !( fc->oformat->flags & AVFMT_NOFILE ) && fc->pb )
        avio_close( fc->pb );
    
    av_free( fc );
}



// Since the data may not from ffmpeg as AVPacket format
void h264_file_write_frame(AVFormatContext *fc, int vStreamIdx, const void* p, int len, int64_t dts, int64_t pts )
{
    AVStream *pst = NULL;
    AVPacket pkt;
    
    if ( 0 > vVideoStreamIdx )
        return;

    // may be audio or video
    pst = fc->streams[ vStreamIdx ];
    
    // Init packet
    av_init_packet( &pkt );
    
    if(vStreamIdx ==vVideoStreamIdx)
    {
        pkt.flags |= ( 0 >= getVopType( p, len ) ) ? AV_PKT_FLAG_KEY : 0;
        //pkt.flags |= AV_PKT_FLAG_KEY;
        pkt.stream_index = pst->index;
        pkt.data = (uint8_t*)p;
        pkt.size = len;
    
#if PTS_DTS_IS_CORRECT == 1
        pkt.dts = dts;
        pkt.pts = pts;
#else
        pkt.dts = AV_NOPTS_VALUE;
        pkt.pts = AV_NOPTS_VALUE;
#endif
        // TODO: mark or unmark the log
        //fprintf(stderr, "dts=%lld, pts=%lld\n",dts,pts);
        // av_write_frame( fc, &pkt );
    }
    av_interleaved_write_frame( fc, &pkt );
}

void h264_file_write_audio_frame(AVFormatContext *fc, AVCodecContext *pAudioCodecContext ,int vStreamIdx, const void* pData, int vDataLen, int64_t dts, int64_t pts )
{
    int vRet=0;
    AVCodecContext *pAudioOutputCodecContext;
    AVStream *pst = NULL;
    AVPacket pkt;
    
    if ( 0 > vVideoStreamIdx )
        return;
    
    // may be audio or video
    pst = fc->streams[ vStreamIdx ];
    //pAudioOutputCodecContext = pst->codec;
    pAudioOutputCodecContext = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(pAudioOutputCodecContext, pst->codecpar);
    
    // Init packet
    av_init_packet( &pkt );
    
    if(vStreamIdx==vAudioStreamIdx)
    {
        if(pAudioOutputCodecContext==NULL)
        {
            NSLog(@"pAudioOutputCodecContext==NULL");
        }
        else
        {
            int bIsADTSAAS=0, vRedudantHeaderOfAAC=0;
            //AVPacket AudioPacket={0};
            tAACADTSHeaderInfo vxADTSHeader={0};
            uint8_t *pHeader = (uint8_t *)pData;
            
            bIsADTSAAS = [AudioUtilities parseAACADTSHeader:pHeader ToHeader:(tAACADTSHeaderInfo *) &vxADTSHeader];
            // If header has the syncword of adts_fixed_header
            // syncword = 0xFFF
            if(bIsADTSAAS)
            {
                vRedudantHeaderOfAAC = 7;
            }
            else
            {
                vRedudantHeaderOfAAC = 0;
            }
            
#if 0
            int gotFrame=0, len=0;
            
            AVFrame vxAVFrame1={0};
            AVFrame *pAVFrame1 = &vxAVFrame1;
            
            av_init_packet(&AudioPacket);
            av_frame_unref(pAVFrame1);

            if(bIsADTSAAS)
            {
                AudioPacket.size = vDataLen-vRedudantHeaderOfAAC;
                AudioPacket.data = pHeader+vRedudantHeaderOfAAC;
            }
            else
            {
                // This will produce error message
                // "malformated aac bitstream, use -absf aac_adtstoasc"
                AudioPacket.size = vDataLen;
                AudioPacket.data = pHeader;
            }
            // Decode from input format to PCM
            len = avcodec_decode_audio4(pAudioCodecContext, pAVFrame1, &gotFrame, &AudioPacket);
            
            // Encode from PCM to AAC
            vRet = avcodec_encode_audio2(pAudioOutputCodecContext, &pkt, pAVFrame1, &gotFrame);
            if(vRet!=0)
                NSLog(@"avcodec_encode_audio2 fail");
            pkt.stream_index = vStreamIdx;//pst->index;

#else

            //if(pAudioCodecContext->codec_id==AV_CODEC_ID_AAC)
            {
                // This will produce error message
                // "malformated aac bitstream, use -absf aac_adtstoasc"
                pkt.size = vDataLen-vRedudantHeaderOfAAC;
                pkt.data = pHeader+vRedudantHeaderOfAAC;
                pkt.stream_index = vStreamIdx;//pst->index;
                pkt.flags |= AV_PKT_FLAG_KEY;
                
            }

#endif
//            pkt.dts = AV_NOPTS_VALUE;
//            pkt.pts = AV_NOPTS_VALUE;
            vRet = av_interleaved_write_frame( fc, &pkt );
            if(vRet!=0)
                NSLog(@"av_interleaved_write_frame for audio fail");
        }
    }


}


void h264_file_write_frame2(AVFormatContext *fc, int vStreamIdx, AVPacket *pPkt )
{    
    av_interleaved_write_frame( fc, pPkt );
}


int h264_file_create(const char *pFilePath, AVFormatContext *fc, AVCodecContext *pCodecCtx,AVCodecContext *pAudioCodecCtx, double fps, void *p, int len )
{
    int vRet=0;
    AVOutputFormat *of=NULL;
    AVStream *pst=NULL;
    AVCodecContext *pcc=NULL, *pAudioOutputCodecContext=NULL;

    avcodec_register_all();
    av_register_all();
    av_log_set_level(AV_LOG_VERBOSE);
    
    if(!pFilePath)
    {
        fprintf(stderr, "FilePath no exist");
        return -1;
    }
    
    if(!fc)
    {
        fprintf(stderr, "AVFormatContext no exist");
        return -1;
    }
    fprintf(stderr, "file=%s\n",pFilePath);
    
    // Create container
    of = av_guess_format( 0, pFilePath, 0 );
    fc->oformat = of;
    strcpy( fc->filename, pFilePath );
    
    // Add video stream
    pst = avformat_new_stream( fc, 0 );
    vVideoStreamIdx = pst->index;
    NSLog(@"Video Stream:%d",vVideoStreamIdx);
    
    //pcc = pst->codec;
    pcc = avcodec_alloc_context3(NULL);
    avcodec_parameters_to_context(pcc, pst->codecpar);
    
    avcodec_get_context_defaults3( pcc, AVMEDIA_TYPE_VIDEO );

    // TODO: test here
    //*pcc = *pCodecCtx;
    
    // TODO: check ffmpeg source for "q=%d-%d", some parameter should be set before write header
    
    // Save the stream as origin setting without convert
    pcc->codec_type = pCodecCtx->codec_type;
    pcc->codec_id = pCodecCtx->codec_id;
    pcc->bit_rate = pCodecCtx->bit_rate;
    pcc->width = pCodecCtx->width;
    pcc->height = pCodecCtx->height;
    
#if PTS_DTS_IS_CORRECT == 1
    pcc->time_base.num = pCodecCtx->time_base.num;
    pcc->time_base.den = pCodecCtx->time_base.den;
    pcc->ticks_per_frame = pCodecCtx->ticks_per_frame;
//    pcc->frame_bits= pCodecCtx->frame_bits;
//    pcc->frame_size= pCodecCtx->frame_size;
//    pcc->frame_number= pCodecCtx->frame_number;
    
//    pcc->pts_correction_last_dts = pCodecCtx->pts_correction_last_dts;
//    pcc->pts_correction_last_pts = pCodecCtx->pts_correction_last_pts;
    
    NSLog(@"time_base, num=%d, den=%d, fps should be %g",\
          pcc->time_base.num, pcc->time_base.den, \
          (1.0/ av_q2d(pCodecCtx->time_base)/pcc->ticks_per_frame));
#else
    if(fps==0)
    {
        double fps=0.0;
        AVRational pTimeBase;
        pTimeBase.num = pCodecCtx->time_base.num;
        pTimeBase.den = pCodecCtx->time_base.den;
        fps = 1.0/ av_q2d(pCodecCtx->time_base)/ FFMAX(pCodecCtx->ticks_per_frame, 1);
        NSLog(@"fps_method(tbc): 1/av_q2d()=%g",fps);
        pcc->time_base.num = 1;
        pcc->time_base.den = fps;
    }
    else
    {
        pcc->time_base.num = 1;
        pcc->time_base.den = fps;
    }
#endif
    // reference ffmpeg\libavformat\utils.c

    // For SPS and PPS in avcC container
    pcc->extradata = malloc(sizeof(uint8_t)*pCodecCtx->extradata_size);
    memcpy(pcc->extradata, pCodecCtx->extradata, pCodecCtx->extradata_size);
    pcc->extradata_size = pCodecCtx->extradata_size;
    
    // For Audio stream
    if(pAudioCodecCtx)
    {
        AVCodec *pAudioCodec=NULL;
        AVStream *pst2=NULL;
        pAudioCodec = avcodec_find_encoder(AV_CODEC_ID_AAC);
        
        // Add audio stream
        pst2 = avformat_new_stream( fc, pAudioCodec );
        vAudioStreamIdx = pst2->index;
        
        //pAudioOutputCodecContext = pst2->codec;
        pAudioOutputCodecContext = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(pAudioOutputCodecContext, pst2->codecpar);
        
        avcodec_get_context_defaults3( pAudioOutputCodecContext, pAudioCodec );
        NSLog(@"Audio Stream:%d",vAudioStreamIdx);
        NSLog(@"pAudioCodecCtx->bits_per_coded_sample=%d",pAudioCodecCtx->bits_per_coded_sample);
        
        pAudioOutputCodecContext->codec_type = AVMEDIA_TYPE_AUDIO;
        pAudioOutputCodecContext->codec_id = AV_CODEC_ID_AAC;
        
        // Copy the codec attributes
        pAudioOutputCodecContext->channels = pAudioCodecCtx->channels;
        pAudioOutputCodecContext->channel_layout = pAudioCodecCtx->channel_layout;
        pAudioOutputCodecContext->sample_rate = pAudioCodecCtx->sample_rate;
        pAudioOutputCodecContext->bit_rate = 12000;//pAudioCodecCtx->sample_rate * pAudioCodecCtx->bits_per_coded_sample;
        pAudioOutputCodecContext->bits_per_coded_sample = pAudioCodecCtx->bits_per_coded_sample;
        pAudioOutputCodecContext->profile = pAudioCodecCtx->profile;
        //FF_PROFILE_AAC_LOW;
        // pAudioCodecCtx->bit_rate;
        
        // AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P
        //pAudioOutputCodecContext->sample_fmt = AV_SAMPLE_FMT_FLTP;//pAudioCodecCtx->sample_fmt;
        pAudioOutputCodecContext->sample_fmt = pAudioCodecCtx->sample_fmt;
        //pAudioOutputCodecContext->sample_fmt = AV_SAMPLE_FMT_U8;
        
        pAudioOutputCodecContext->sample_aspect_ratio = pAudioCodecCtx->sample_aspect_ratio;

        pAudioOutputCodecContext->time_base.num = pAudioCodecCtx->time_base.num;
        pAudioOutputCodecContext->time_base.den = pAudioCodecCtx->time_base.den;
        pAudioOutputCodecContext->ticks_per_frame = pAudioCodecCtx->ticks_per_frame;
        pAudioOutputCodecContext->frame_size = 1024;
        
        NSLog(@"profile:%d, sample_rate:%d, channles:%d", pAudioOutputCodecContext->profile, pAudioOutputCodecContext->sample_rate, pAudioOutputCodecContext->channels);
        AVDictionary *opts = NULL;
        av_dict_set(&opts, "strict", "experimental", 0);
        
        if (avcodec_open2(pAudioOutputCodecContext, pAudioCodec, &opts) < 0) {
            fprintf(stderr, "\ncould not open codec\n");
        }
        
        av_dict_free(&opts);
        
#if 0
        // For Audio, this part is no need
        if(pAudioCodecCtx->extradata_size!=0)
        {
            NSLog(@"extradata_size !=0");
            pAudioOutputCodecContext->extradata = malloc(sizeof(uint8_t)*pAudioCodecCtx->extradata_size);
            memcpy(pAudioOutputCodecContext->extradata, pAudioCodecCtx->extradata, pAudioCodecCtx->extradata_size);
            pAudioOutputCodecContext->extradata_size = pAudioCodecCtx->extradata_size;
        }
        else
        {
            // For WMA test only
            pAudioOutputCodecContext->extradata_size = 0;
            NSLog(@"extradata_size ==0");
        }
#endif
    }
    
    if(fc->oformat->flags & AVFMT_GLOBALHEADER)
    {
        pcc->flags |= CODEC_FLAG_GLOBAL_HEADER;
        pAudioOutputCodecContext->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }
    
    if ( !( fc->oformat->flags & AVFMT_NOFILE ) )
    {
        vRet = avio_open( &fc->pb, fc->filename, AVIO_FLAG_WRITE );
        if(vRet!=0)
        {
            NSLog(@"avio_open(%s) error", fc->filename);
        }
    }
    
    // dump format in console
    av_dump_format(fc, 0, pFilePath, 1);
    
    vRet = avformat_write_header( fc, NULL );
    if(vRet==0)
        return true;
    else
        return false;
}
