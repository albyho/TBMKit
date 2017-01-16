//
//  TBMCamera.h
//  TBMKit
//
//  Created by alby on 2017/1/14.
//  Copyright © 2017年 alby. All rights reserved.
//

@import Foundation;
@import AVFoundation;

typedef NS_ENUM( NSInteger, TBMCameraSetupResult ) {
    TBMCameraSetupResultSuccess,
    TBMCameraSetupResultUnknowError,
    TBMCameraSetupResultCameraNotAuthorized,
    TBMCameraSetupResultMicrophoneNotAuthorized,
    TBMCameraSetupResultSessionConfigurationFailed
};

@class TBMCamera, TBMCameraPreviewView;

@protocol TBMCameraDelegate <NSObject>

// Setup
- (void)tbmCameraSetup:(TBMCamera *)camera setupResult:(TBMCameraSetupResult)setupResult;

/*!
 @method tbmCameraCaptureSessionPreset:
 @example
 return AVCaptureSessionPresetHigh;
 */
- (NSString *)tbmCameraCaptureSessionPreset:(TBMCamera *)camera;            // 非主线程

/*!
 @method tbmCameraCaptureDevice:
 @example
 < iOS 10.0
 NSArray *videoDevices  = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
 for (AVCaptureDevice *videoDevice in devices) {
 if ([videoDevice position] == AVCaptureDevicePositionBack) {
    return videoDevice;
 }
 或：
 return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
 
 >= iOS 10.0
 AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                   mediaType:AVMediaTypeVideo
                                                                    position:AVCaptureDevicePositionUnspecified];
 return videoDevice;
 */
- (AVCaptureDevice *)tbmCameraInitialVideoDevice:(TBMCamera *)camera;       // 非主线程
- (void)tbmCameraWillConfigureCaptureOutput:(TBMCamera *)camera;
- (BOOL)tbmCameraConfigureCaptureOutput:(TBMCamera *)camera;                // 非主线程
- (void)tbmCameraDidConfigureCaptureOutput:(TBMCamera *)camera;

// Device Configuration
/*!
 @method tbmCameraDeviceWillChange:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraDeviceWillChange:(TBMCamera *)camera;
/*!
 @method tbmCameraDeviceChangingConfigure:
 @example
 >= iOS 8.0
 AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
 if ( connection.isVideoStabilizationSupported ) {
 connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
 }
 */
- (void)tbmCameraDeviceChangingConfigure:(TBMCamera *)camera;    // 非主线程
/*!
 @method tbmCameraDeviceWillChange:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraDeviceDidChange:(TBMCamera *)camera;

// Focus
- (void)tbmCameraFocusModeDidChange:(TBMCamera *)camera newValue:(AVCaptureFocusMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue;
- (void)tbmCameraLensPositionDidChange:(TBMCamera *)camera newValue:(AVCaptureFocusMode)newValue;

// Exposure
- (void)tbmCameraExposureModeDidChange:(TBMCamera *)camera newValue:(AVCaptureExposureMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue;
- (void)tbmCameraExposureDurationDidChange:(TBMCamera *)camera newValue:(Float32)newValue;
- (void)tbmCameraISODidChange:(TBMCamera *)camera newValue:(Float32)newValue;
- (void)tbmCameraExposureTargetBiasDidChange:(TBMCamera *)camera newValue:(Float32)newValue;
- (void)tbmCameraExposureTargetOffsetDidChange:(TBMCamera *)camera newValue:(Float32)newValue;

// WhiteBalance
- (void)tbmCameraWhiteBalanceModeDidChange:(TBMCamera *)camera newValue:(AVCaptureWhiteBalanceMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue;
- (void)tbmCameraDeviceWhiteBalanceGainsDidChange:(TBMCamera *)camera newValue:(AVCaptureWhiteBalanceTemperatureAndTintValues)newValue;

// Session
- (void)tbmCameraSessionRunningStateDidChange:(TBMCamera *)camera newValue:(BOOL)newValue;

// Interruption
- (void)tbmCameraSessionRuntimeError:(TBMCamera *)camera notification:(NSNotification *)notification;
- (void)tbmCameraSessionWasInterrupted:(TBMCamera *)camera notification:(NSNotification *)notification;
- (void)tbmCameraSessionInterruptionEnded:(TBMCamera *)camera notification:(NSNotification *)notification;

@end

/*!
 @class TBMCamera
 @abstract
 TBMCamera 用于视频录制.
 
 @discussion
 TBMCamera 不直接写入文件或进行网络传输.
 */
@interface TBMCamera : NSObject

@property (nonatomic, weak)         id<TBMCameraDelegate> delegate;

@property (nonatomic, readonly)     TBMCameraPreviewView *previewView;

@property (nonatomic, readonly)     AVCaptureSession *session;
@property (nonatomic, readonly)     AVCaptureDevice *videoDevice;
@property (nonatomic, readonly)     AVCaptureDevice *audioDevice;

- (BOOL)setup;
/*!
 @method tbmCameraCaptureSessionPreset:
 @example
 获取所有可用的视频设备：
 < iOS 10.0
 NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
 
 >= iOS 10.0
 NSArray<NSString *> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera, AVCaptureDeviceTypeBuiltInTelephotoCamera];
 self.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
 NSArray *videoDevices = self.videoDeviceDiscoverySession.devices;
 */
- (void)changeCameraWithDevice:(AVCaptureDevice *)newVideoDevice;
- (void)changeFocusMode:(AVCaptureFocusMode)focusMode;
- (void)start;
- (void)stop;

@end
