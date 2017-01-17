//
//  TBMFileRecorder.m
//  TBMKit
//
//  Created by alby on 2017/1/17.
//  Copyright © 2017年 alby. All rights reserved.
//

@import AVFoundation;
#import "TBMMovieFileRecorder.h"
#import "TBMCamera.h"
#import "TBMCameraPreviewView.h"

@interface TBMMovieFileRecorder ()<TBMCameraDelegate, AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, readwrite)     TBMCamera *camera;
@property (nonatomic, readwrite)     TBMCameraPreviewView *previewView;

@end

@implementation TBMMovieFileRecorder

#pragma mark - TBMCameraDelegate

#pragma mark - AVCaptureFileOutputRecordingDelegate

@end
