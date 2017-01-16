//
//  TBMCameraPreviewView.h
//  TBMKit
//
//  Created by alby on 2017/1/14.
//  Copyright © 2017年 alby. All rights reserved.
//

@import UIKit;

@class AVCaptureSession;

@interface TBMCameraPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
