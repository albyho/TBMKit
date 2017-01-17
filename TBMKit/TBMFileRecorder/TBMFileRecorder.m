//
//  TBMFileRecorder.m
//  TBMKit
//
//  Created by alby on 2017/1/17.
//  Copyright © 2017年 alby. All rights reserved.
//

@import AVFoundation;
#import "TBMFileRecorder.h"
#import "TBMCamera.h"
#import "TBMCameraPreviewView.h"

@interface TBMFileRecorder ()<TBMCameraDelegate, AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, readwrite)     TBMCamera *camera;
@property (nonatomic, readwrite)     TBMCameraPreviewView *previewView;

@end

@implementation TBMFileRecorder

#pragma mark - TBMCameraDelegate

#pragma mark - AVCaptureFileOutputRecordingDelegate

@end
