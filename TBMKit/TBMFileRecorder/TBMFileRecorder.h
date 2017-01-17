//
//  TBMFileRecorder.h
//  TBMKit
//
//  Created by alby on 2017/1/17.
//  Copyright © 2017年 alby. All rights reserved.
//

@import Foundation;

@class TBMCamera, TBMCameraPreviewView;

@interface TBMFileRecorder : NSObject

@property (nonatomic, readonly)     TBMCamera *camera;
@property (nonatomic, readonly)     TBMCameraPreviewView *previewView;

@end
