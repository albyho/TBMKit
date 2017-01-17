//
//  TBMCamera.h
//  TBMKit
//
//  Created by alby on 2017/1/14.
//  Copyright © 2017年 alby. All rights reserved.
//

@import Foundation;
@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM( NSInteger, TBMCameraSetupResult ) {
    TBMCameraSetupResultSuccess,
    TBMCameraSetupResultUnknowError,
    TBMCameraSetupResultCameraNotAuthorized,
    TBMCameraSetupResultMicrophoneNotAuthorized,
    TBMCameraSetupResultSessionConfigurationFailed
};

@class TBMCamera, TBMCameraPreviewView;

@protocol TBMCameraDelegate <NSObject>

@required
// Setup
/*!
 @method tbmCameraDidSetup:setupResult:
 @discussion
 Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
 handled by -[TBMCameraViewController viewWillTransitionToSize:withTransitionCoordinator:].

 @example
 if(setupResult == TBMCameraSetupResultSuccess) {
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
    if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
        initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
    }

    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)caller.previewView.layer;
        previewLayer.connection.videoOrientation = initialVideoOrientation;
    } );
 }
 */
- (void)tbmCameraDidSetup:(TBMCamera *)camera setupResult:(TBMCameraSetupResult)setupResult;

/*!
 @method tbmCameraCaptureSessionPreset:
 @example
 return AVCaptureSessionPresetHigh;
 */
- (NSString *)tbmCameraCaptureSessionPreset:(TBMCamera *)camera;            // 非主线程

/*!
 @method tbmCameraCaptureSessionWasInitialized:
 @example
 // Set up the preview view
 caller.previewView.session = camera.session;
 */
- (void)tbmCameraCaptureSessionWasInitialized:(TBMCamera *)camera;
/*!
 @method tbmCameraInitialVideoDevice:
 @example
 < iOS 10.0
 NSArray *videoDevices  = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
 for (AVCaptureDevice *videoDevice in devices) {
    if ([videoDevice position] == AVCaptureDevicePositionBack) {
        return videoDevice;
    }
 }
 或：
 return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
 
 >= iOS 10.0
 NSArray<NSString *> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera, AVCaptureDeviceTypeBuiltInTelephotoCamera];
 caller.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
 NSArray *videoDevices = caller.videoDeviceDiscoverySession.devices;
 for (AVCaptureDevice *videoDevice in devices) {
    if ([videoDevice position] == AVCaptureDevicePositionBack) {
        return videoDevice;
    }
 }
 或：
 AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                   mediaType:AVMediaTypeVideo
                                                                    position:AVCaptureDevicePositionUnspecified];
 return videoDevice;
 */
- (AVCaptureDevice *)tbmCameraInitialVideoDevice:(TBMCamera *)camera;       // 非主线程
/*!
 @method tbmCameraWillConfigureCaptureOutput:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraWillConfigureCaptureOutput:(TBMCamera *)camera;
/*!
 @method tbmCameraConfigureCaptureOutput:
 @example
 AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
 
 if ( [camera.session canAddOutput:movieFileOutput] ) {
    [camera.session beginConfiguration];
    [camera.session addOutput:movieFileOutput];
    camera.session.sessionPreset = AVCaptureSessionPresetHigh;
    AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    if ( connection.isVideoStabilizationSupported ) {
        connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    [caller.session commitConfiguration];
 
    caller.movieFileOutput = movieFileOutput;
 
    dispatch_async( dispatch_get_main_queue(), ^{
        // 可进行必要的 UI 设置。比如，录制按钮可用。
    } );
 }
 */
- (BOOL)tbmCameraConfigureCaptureOutput:(TBMCamera *)camera;                // 非主线程
/*!
 @method tbmCameraDidConfigureCaptureOutput:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraDidConfigureCaptureOutput:(TBMCamera *)camera;

// Device Configuration
/*!
 @method tbmCameraDeviceWillChange:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraDeviceWillChange:(TBMCamera *)camera;
/*!
 @method tbmCameraDeviceChanging:
 @example
 >= iOS 8.0
 AVCaptureConnection *connection = [caller.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
 if ( connection.isVideoStabilizationSupported ) {
    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
 }
 */
- (void)tbmCameraDeviceChanging:(TBMCamera *)camera;    // 非主线程
/*!
 @method tbmCameraDeviceWillChange:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraDeviceDidChange:(TBMCamera *)camera;

@optional
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
/*!
 @method tbmCameraSessionRuntimeError:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraSessionRuntimeError:(TBMCamera *)camera notification:(NSNotification *)notification;
/*!
 @method tbmCameraSessionWasInterrupted:
 @example
 可进行必要的 UI 设置
 */
- (void)tbmCameraSessionWasInterrupted:(TBMCamera *)camera notification:(NSNotification *)notification;
/*!
 @method tbmCameraSessionInterruptionEnded:
 @example
 可进行必要的 UI 设置
 */
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

@property (nonatomic, readonly)     AVCaptureSession *session;
@property (nonatomic, readonly)     AVCaptureDevice *videoDevice;
@property (nonatomic, readonly)     AVCaptureDevice *audioDevice;

- (void)setup;
/*!
 @method tbmCameraCaptureSessionPreset:
 @example
 获取所有可用的视频设备：
 < iOS 10.0
 NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
 
 >= iOS 10.0
 NSArray<NSString *> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera, AVCaptureDeviceTypeBuiltInTelephotoCamera];
 caller.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
 NSArray *videoDevices = caller.videoDeviceDiscoverySession.devices;
 */
- (void)changeCameraWithDevice:(AVCaptureDevice *)videoDevice;
- (void)changeFocusMode:(AVCaptureFocusMode)focusMode;
- (void)changeLensPosition:(float)lensPosition;
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange;
- (void)changeExposureMode:(AVCaptureExposureMode)exposureMode;
- (void)changeExposureDuration:(float)exposureDuration;
- (void)changeISO:(float)ISO;
- (void)changeExposureTargetBias:(float)exposureTargetBias;
- (void)changeWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode;
- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)gains;
- (void)changeTemperatureAndTint:(float)temperature tint:(float)tint;
- (void)lockWithGrayWorld;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
