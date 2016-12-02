//
//  iFrameExtractorViewController.h
//  iFrameExtractor
//
//  Created by Liao KuoHsun on 2016/11/24.
//
//

#import <UIKit/UIKit.h>

@class VideoFrameExtractor;

#define RECORDING_AT_RTSP_START 0
//#define RECORDING_AT_RTSP_START 1
#define RECPRDING_SECONDS 5

@interface iFrameExtractorViewController : UIViewController {
    //VideoFrameExtractor *video;
    float lastFrameTime;
}
@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UILabel *label;
@property (nonatomic, retain) IBOutlet UIButton *playButton;
@property (nonatomic, retain) VideoFrameExtractor *video;
@property (retain, nonatomic) IBOutlet UIButton *RecordButton;
@property (retain, nonatomic) IBOutlet UIButton *SnapShotButton;
@property (retain, nonatomic) IBOutlet UILabel *RecordProgressLevel;
@property (nonatomic) int vRecordSeconds;


-(IBAction)playButtonAction:(id)sender;
- (IBAction)SnapShotButtonAction:(id)sender;
- (IBAction)RecordButtionAction:(id)sender;

@end
