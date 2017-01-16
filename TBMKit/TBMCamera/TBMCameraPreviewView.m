//
//  TBMCameraPreviewView.m
//  TBMKit
//
//  Created by alby on 2017/1/14.
//  Copyright © 2017年 alby. All rights reserved.
//

@import AVFoundation;

#import "TBMCameraPreviewView.h"

@implementation TBMCameraPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    return previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    previewLayer.session = session;
}

@end
