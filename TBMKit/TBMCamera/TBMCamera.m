//
//  TBMCamera.m
//  TBMKit
//
//  Created by alby on 2017/1/14.
//  Copyright © 2017年 alby. All rights reserved.
//

@import AVFoundation;
@import Photos;

#import "TBMCamera.h"

static void *SessionRunningContext = &SessionRunningContext;
static void *FocusModeContext = &FocusModeContext;
static void *ExposureModeContext = &ExposureModeContext;
static void *WhiteBalanceModeContext = &WhiteBalanceModeContext;
static void *LensPositionContext = &LensPositionContext;
static void *ExposureDurationContext = &ExposureDurationContext;
static void *ISOContext = &ISOContext;
static void *ExposureTargetBiasContext = &ExposureTargetBiasContext;
static void *ExposureTargetOffsetContext = &ExposureTargetOffsetContext;
static void *DeviceWhiteBalanceGainsContext = &DeviceWhiteBalanceGainsContext;

static void *SessionQueueKey = &SessionQueueKey;

@interface TBMCamera()

// Session management
@property (nonatomic)               dispatch_queue_t sessionQueue;
@property (nonatomic, readwrite)    AVCaptureSession *session;
@property (nonatomic, readwrite)    AVCaptureDevice *videoDevice;
@property (nonatomic)               AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, readwrite)    AVCaptureDevice *audioDevice;
@property (nonatomic)               AVCaptureDeviceInput *audioDeviceInput;

// Utilities
@property (nonatomic) TBMCameraSetupResult      setupResult;
@property (nonatomic, getter=isSessionRunning)  BOOL sessionRunning;

@end

@implementation TBMCamera

static const float kExposureDurationPower = 5; // Higher numbers will give the slider more sensitivity at shorter durations
static const float kExposureMinimumDuration = 1.0/1000; // Limit exposure duration to a useful range

- (void)dealloc {
    NSLog(@"%s", __FUNCTION__);
}

- (void)setup {
    if ( ![NSThread isMainThread] ) {
        NSLog(@"%s %@", __FUNCTION__, @"请在主线程调用");
    }
    
    // Communicate with the session and other session objects on this queue
    self.sessionQueue = dispatch_queue_create( "com.tbmkit.camera.sessionqueue", DISPATCH_QUEUE_SERIAL );
    dispatch_queue_set_specific(self.sessionQueue, SessionQueueKey, (__bridge void *)self, NULL);
    
    // Check audio and video authorization status (Audio First)
    [self checkAuthorizationStatus:AVMediaTypeAudio];

    // Create the AVCaptureSession
    self.session = [[AVCaptureSession alloc] init];

    [self tbmCameraCaptureSessionWasInitializedNotify:self];
    
    self.setupResult = TBMCameraSetupResultSuccess;
    
    // Setup the capture session.
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
    // so that the main queue isn't blocked, which keeps the UI responsive.
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        [self configureSession];
    });

}

- (void)start {
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult == TBMCameraSetupResultSuccess ) {
            // Only setup observers and start the session running if setup succeeded
            [self addObservers];
            [self.session startRunning];
            self.sessionRunning = self.session.isRunning;
        }
    } );
}

- (void)stop
{
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult == TBMCameraSetupResultSuccess ) {
            [self.session stopRunning];
            [self removeObservers];
        }
    } );
}

#pragma mark - Session Management

// Should be called on the session queue
- (void)configureSession
{
    if ( self.setupResult != TBMCameraSetupResultSuccess ) {
        return;
    }
    
    NSError *error = nil;
    
    [self.session beginConfiguration];
    
    self.session.sessionPreset = [self tbmCameraCaptureSessionPresetNotify:self];
    
    // Add video input
    AVCaptureDevice *videoDevice = [self tbmCameraInitialVideoDeviceNotify:self];
    if ( ! videoDevice ) {
        NSLog( @"Could not create video device" );
        self.setupResult = TBMCameraSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
        return;
    }
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if ( ! videoDeviceInput ) {
        NSLog( @"Could not create video device input: %@", error );
        self.setupResult = TBMCameraSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
        return;
    }
    if ( [self.session canAddInput:videoDeviceInput] ) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
        self.videoDevice = videoDevice;        
    }
    else {
        NSLog( @"Could not add video device input to the session" );
        self.setupResult = TBMCameraSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
        return;
    }
    
    // Add audio input
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.audioDevice error:&error];
    if ( ! self.audioDeviceInput ) {
        NSLog( @"Could not create audio device input: %@", error );
    }
    if ( [self.session canAddInput:self.audioDeviceInput] ) {
        [self.session addInput:self.audioDeviceInput];
    }
    else {
        NSLog( @"Could not add audio device input to the session" );
    }
    
    [self tbmCameraWillConfigureCaptureOutputNotify:self];
    if ( ![self tbmCameraConfigureCaptureOutputNotify:self] ) {
        self.setupResult = TBMCameraSetupResultSessionConfigurationFailed;
        [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
        [self.session commitConfiguration];
        return;
    }
    [self tbmCameraDidConfigureCaptureOutputNotify:self];
    
    [self.session commitConfiguration];
    [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
}

#pragma mark - TBMCameraDelegate

// Setup
- (void)tbmCameraDidSetupNotify:(TBMCamera *)camera setupResult:(TBMCameraSetupResult)setupResult {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraDidSetup:setupResult:)] ) {
        runAsynchronouslyOnMainQueue(^{
            [self.delegate tbmCameraDidSetup:camera setupResult:setupResult];
        });
    }
}
// Should be called on the session queue
- (NSString *)tbmCameraCaptureSessionPresetNotify:(TBMCamera *)camera {
    // 非主线程
    if ( [self.delegate respondsToSelector:@selector(tbmCameraCaptureSessionPreset:)] ) {
        return [self.delegate tbmCameraCaptureSessionPreset:camera];
    }
    return AVCaptureSessionPresetHigh;
}
- (void)tbmCameraCaptureSessionWasInitializedNotify:(TBMCamera *)camera {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraCaptureSessionWasInitialized:)] ) {
        runAsynchronouslyOnMainQueue(^{
            [self.delegate tbmCameraCaptureSessionWasInitialized:camera];
        });
    }
}
- (AVCaptureDevice *)tbmCameraInitialVideoDeviceNotify:(TBMCamera *)camera {
    // 非主线程
    if ( [self.delegate respondsToSelector:@selector(tbmCameraInitialVideoDevice:)] ) {
        return [self.delegate tbmCameraInitialVideoDevice:camera];
    }
    return nil;
}
- (void)tbmCameraWillConfigureCaptureOutputNotify:(TBMCamera *)camera {
    runAsynchronouslyOnMainQueue(^{
        [self.delegate tbmCameraWillConfigureCaptureOutput:camera];
    });
}
- (BOOL)tbmCameraConfigureCaptureOutputNotify:(TBMCamera *)camera {
    // 非主线程
    if ( [self.delegate respondsToSelector:@selector(tbmCameraConfigureCaptureOutput:)] ) {
        return [self.delegate tbmCameraConfigureCaptureOutput:camera];
    }
    return NO;
}
- (void)tbmCameraDidConfigureCaptureOutputNotify:(TBMCamera *)camera {
    runAsynchronouslyOnMainQueue(^{
        [self.delegate tbmCameraDidConfigureCaptureOutput:camera];
    });
}

// Device Configuration
- (void)tbmCameraDeviceWillChangeNotify:(TBMCamera *)camera {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraDeviceWillChange:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraDeviceWillChange:camera];
        });
    }
}
- (void)tbmCameraDeviceChangingNotify:(TBMCamera *)camera {
    // 非主线程
    if ( [self.delegate respondsToSelector:@selector(tbmCameraDeviceChanging:)] ) {
        return [self.delegate tbmCameraDeviceChanging:camera];
    }
}
- (void)tbmCameraDeviceDidChangeNotify:(TBMCamera *)camera {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraDeviceDidChange:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraDeviceDidChange:camera];
        });
    }
}

// Focus
- (void)tbmCameraFocusModeDidChangeNotify:(TBMCamera *)camera newValue:(AVCaptureFocusMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraFocusModeDidChange:newValue:oldValue:)] ) {
    }
}
- (void)tbmCameraLensPositionDidChangeNotify:(TBMCamera *)camera newValue:(Float32)newValue{
    if ( [self.delegate respondsToSelector:@selector(tbmCameraLensPositionDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraLensPositionDidChange:camera newValue:newValue];
        });
    }
}

// Exposure
- (void)tbmCameraExposureModeDidChangeNotify:(TBMCamera *)camera newValue:(AVCaptureExposureMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraExposureModeDidChange:newValue:oldValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraExposureModeDidChange:camera newValue:newValue oldValue:oldValue];
        });
    }
}
- (void)tbmCameraExposureDurationDidChangeNotify:(TBMCamera *)camera newValue:(Float32)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraExposureDurationDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraExposureDurationDidChange:camera newValue:newValue];
        });
    }
}
- (void)tbmCameraISODidChangeNotify:(TBMCamera *)camera newValue:(Float32)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraISODidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraISODidChange:camera newValue:newValue];
        });
    }
}
- (void)tbmCameraExposureTargetBiasDidChangeNotify:(TBMCamera *)camera newValue:(Float32)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraExposureTargetBiasDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraExposureTargetBiasDidChange:camera newValue:newValue];
        });
    }
}
- (void)tbmCameraExposureTargetOffsetDidChangeNotify:(TBMCamera *)camera newValue:(Float32)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraExposureTargetOffsetDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraExposureTargetOffsetDidChange:camera newValue:newValue];
        });
    }
}

// White Balance
- (void)tbmCameraWhiteBalanceModeDidChangeNotify:(TBMCamera *)camera newValue:(AVCaptureWhiteBalanceMode)newValue oldValue:(id/*可能没有值，为NSNull*/)oldValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraWhiteBalanceModeDidChange:newValue:oldValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraWhiteBalanceModeDidChange:camera newValue:newValue oldValue:oldValue];
        });
    }
}
- (void)tbmCameraDeviceWhiteBalanceGainsDidChangeNotify:(TBMCamera *)camera newValue:(AVCaptureWhiteBalanceTemperatureAndTintValues)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraDeviceWhiteBalanceGainsDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraDeviceWhiteBalanceGainsDidChange:camera newValue:newValue];
        });
    }
}
// Session
- (void)tbmCameraSessionRunningStateDidChangeNotify:(TBMCamera *)camera newValue:(BOOL)newValue {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraSessionRunningStateDidChange:newValue:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraSessionRunningStateDidChange:camera newValue:newValue];
        });
    }
}

// Interruption
- (void)tbmCameraSessionRuntimeErrorNotify:(TBMCamera *)camera notification:(NSNotification *)notification {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraSessionRuntimeError:notification:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraSessionRuntimeError:camera notification:notification];
        });
    }
}
- (void)tbmCameraSessionWasInterruptedNotify:(TBMCamera *)camera notification:(NSNotification *)notification {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraSessionWasInterrupted:notification:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraSessionWasInterrupted:camera notification:notification];
        });
    }
}
- (void)tbmCameraSessionInterruptionEndedNotify:(TBMCamera *)camera notification:(NSNotification *)notification {
    if ( [self.delegate respondsToSelector:@selector(tbmCameraSessionInterruptionEnded:notification:)] ) {
        runAsynchronouslyOnMainQueue(^{
            return [self.delegate tbmCameraSessionInterruptionEnded:camera notification:notification];
        });
    }
}

#pragma mark - KVO and Notifications

- (void)addObservers
{
    [self addObserver:self forKeyPath:@"session.running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    [self addObserver:self forKeyPath:@"videoDevice.focusMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:FocusModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.lensPosition" options:NSKeyValueObservingOptionNew context:LensPositionContext]; // iOS 8.0
    [self addObserver:self forKeyPath:@"videoDevice.exposureMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:ExposureModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureDuration" options:NSKeyValueObservingOptionNew context:ExposureDurationContext];  // iOS 8.0
    [self addObserver:self forKeyPath:@"videoDevice.ISO" options:NSKeyValueObservingOptionNew context:ISOContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureTargetBias" options:NSKeyValueObservingOptionNew context:ExposureTargetBiasContext]; // iOS 8.0
    [self addObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" options:NSKeyValueObservingOptionNew context:ExposureTargetOffsetContext]; // iOS 8.0
    [self addObserver:self forKeyPath:@"videoDevice.whiteBalanceMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:WhiteBalanceModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.deviceWhiteBalanceGains" options:NSKeyValueObservingOptionNew context:DeviceWhiteBalanceGainsContext]; // iOS 8.0
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDevice];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    // A session can only run when the app is full screen. It will be interrupted in a multi-app layout, introduced in iOS 9,
    // see also the documentation of AVCaptureSessionInterruptionReason. Add observers to handle these session interruptions
    // and show a preview is paused message. See the documentation of AVCaptureSessionWasInterruptedNotification for other
    // interruption reasons.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self removeObserver:self forKeyPath:@"session.running" context:SessionRunningContext];
    [self removeObserver:self forKeyPath:@"videoDevice.focusMode" context:FocusModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.lensPosition" context:LensPositionContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureMode" context:ExposureModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureDuration" context:ExposureDurationContext];
    [self removeObserver:self forKeyPath:@"videoDevice.ISO" context:ISOContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureTargetBias" context:ExposureTargetBiasContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" context:ExposureTargetOffsetContext];
    [self removeObserver:self forKeyPath:@"videoDevice.whiteBalanceMode" context:WhiteBalanceModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.deviceWhiteBalanceGains" context:DeviceWhiteBalanceGainsContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    if ( context == FocusModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureFocusMode newMode = [newValue intValue];
            [self tbmCameraFocusModeDidChangeNotify:self newValue:newMode oldValue:oldValue];
            // 当为 AVCaptureFocusModeLocked 时，可设置 LensPosition
        }
    }
    else if ( context == LensPositionContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newLensPosition = [newValue floatValue];
            [self tbmCameraLensPositionDidChangeNotify:self newValue:newLensPosition];
        }
    }
    else if ( context == ExposureModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureExposureMode newMode = [newValue intValue];
            if ( oldValue && oldValue != [NSNull null] ) {
                AVCaptureExposureMode oldMode = [oldValue intValue];
                /*
                 It’s important to understand the relationship between exposureDuration and the minimum frame rate as represented by activeVideoMaxFrameDuration.
                 In manual mode, if exposureDuration is set to a value that's greater than activeVideoMaxFrameDuration, then activeVideoMaxFrameDuration will
                 increase to match it, thus lowering the minimum frame rate. If exposureMode is then changed to automatic mode, the minimum frame rate will
                 remain lower than its default. If this is not the desired behavior, the min and max frameRates can be reset to their default values for the
                 current activeFormat by setting activeVideoMaxFrameDuration and activeVideoMinFrameDuration to kCMTimeInvalid.
                 */
                if ( oldMode != newMode && oldMode == AVCaptureExposureModeCustom ) {
                    NSError *error = nil;
                    if ( [self.videoDevice lockForConfiguration:&error] ) {
                        self.videoDevice.activeVideoMaxFrameDuration = kCMTimeInvalid;
                        self.videoDevice.activeVideoMinFrameDuration = kCMTimeInvalid;
                        [self.videoDevice unlockForConfiguration];
                    }
                    else {
                        NSLog( @"Could not lock device for configuration: %@", error );
                    }
                }
            }
            
            [self tbmCameraExposureModeDidChangeNotify:self newValue:newMode oldValue:oldValue];
            // 当为 AVCaptureExposureModeCustom 时，可设置 exposureDuration 、 ISO 和 Bias；当为 AVCaptureExposureModeLocked 时，可设置 Bias 。
        }
    }
    else if ( context == ExposureDurationContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            double newDurationSeconds = CMTimeGetSeconds( [newValue CMTimeValue] );
            [self tbmCameraExposureDurationDidChangeNotify:self newValue:newDurationSeconds];
        }
    }
    else if ( context == ISOContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newISO = [newValue floatValue];
            [self tbmCameraISODidChangeNotify:self newValue:newISO];
        }
    }
    else if ( context == ExposureTargetBiasContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newExposureTargetBias = [newValue floatValue];
            [self tbmCameraExposureTargetBiasDidChangeNotify:self newValue:newExposureTargetBias];
        }
    }
    else if ( context == ExposureTargetOffsetContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newExposureTargetOffset = [newValue floatValue];
            [self tbmCameraExposureTargetOffsetDidChangeNotify:self newValue:newExposureTargetOffset];
        }
    }
    else if ( context == WhiteBalanceModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureWhiteBalanceMode newMode = [newValue intValue];
            [self tbmCameraWhiteBalanceModeDidChangeNotify:self newValue:newMode oldValue:oldValue];
        }
    }
    else if ( context == DeviceWhiteBalanceGainsContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureWhiteBalanceGains newGains;
            [newValue getValue:&newGains];
            AVCaptureWhiteBalanceTemperatureAndTintValues newTemperatureAndTint = [self.videoDevice temperatureAndTintValuesForDeviceWhiteBalanceGains:newGains];
            [self tbmCameraDeviceWhiteBalanceGainsDidChangeNotify:self newValue:newTemperatureAndTint];
            // 当为 AVCaptureWhiteBalanceModeLocked 时，可设置 Temperature 和 Tint
        }
    }
    else if ( context == SessionRunningContext ) {
        BOOL isRunning = NO;
        if ( newValue && newValue != [NSNull null] ) {
            isRunning = [newValue boolValue];
        }
        [self tbmCameraSessionRunningStateDidChangeNotify:self newValue:isRunning];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:self.videoDevice.focusMode exposeWithMode:self.videoDevice.exposureMode atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog( @"Capture session runtime error: %@", error );
    
    if ( error.code == AVErrorMediaServicesWereReset ) {
        runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
            // If we aren't trying to resume the session, try to restart it, since it must have been stopped due to an error (see -[resumeInterruptedSession:])
            if ( self.isSessionRunning ) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
            else {
                [self tbmCameraSessionRuntimeErrorNotify:self notification:notification];
            }
        });
    }
    else {
        [self tbmCameraSessionRuntimeErrorNotify:self notification:notification];
    }
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
    NSLog( @"Capture session was  interrupted" );
    // In some scenarios we want to enable the user to restart the capture session.
    // For example, if music playback is initiated via Control Center while using AVCamManual,
    // then the user can let AVCamManual resume the session running, which will stop music playback.
    // Note that stopping music playback in Control Center will not automatically resume the session.
    // Also note that it is not always possible to resume, see -[resumeInterruptedSession:].
    // In iOS 9 and later, the notification's userInfo dictionary contains information about why the session was interrupted
    [self tbmCameraSessionWasInterruptedNotify:self notification:notification];
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    NSLog( @"Capture session interruption ended" );
    [self tbmCameraSessionInterruptionEndedNotify:self notification:notification];
}

#pragma mark - Device Configuration

- (void)changeCameraWithDevice:(AVCaptureDevice *)videoDevice
{
    // Check if device changed
    if ( videoDevice == self.videoDevice ) {
        return;
    }
    
    [self tbmCameraDeviceWillChangeNotify:self];
    
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        
        [self.session beginConfiguration];
        
        // Remove the existing device input first, since using the front and back camera simultaneously is not supported
        [self.session removeInput:self.videoDeviceInput];
        if ( [self.session canAddInput:videoDeviceInput] ) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDevice];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
            self.videoDevice = videoDevice;
        }
        else {
            [self.session addInput:self.videoDeviceInput];
        }
        
        [self tbmCameraDeviceChangingNotify:self];
        
        [self.session commitConfiguration];
        
        [self tbmCameraDeviceDidChangeNotify:self];
    } );
}

- (void)changeFocusMode:(AVCaptureFocusMode)focusMode
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            if ( [self.videoDevice isFocusModeSupported:focusMode] ) {
                self.videoDevice.focusMode = focusMode;
            }
            else {
                NSLog( @"Focus mode %@ is not supported. Focus mode is %@.", [self stringFromFocusMode:focusMode], [self stringFromFocusMode:self.videoDevice.focusMode] );
            }
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeLensPosition:(float)lensPosition
{
    // TODO: 参数合法性校验
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            [self.videoDevice setFocusModeLockedWithLensPosition:lensPosition completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        AVCaptureDevice *device = self.videoDevice;
        
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation
            // Call -set(Focus/Exposure)Mode: to apply the new point of interest
            if ( focusMode != AVCaptureFocusModeLocked && device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if ( exposureMode != AVCaptureExposureModeCustom && device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeExposureMode:(AVCaptureExposureMode)exposureMode
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            if ( [self.videoDevice isExposureModeSupported:exposureMode] ) {
                self.videoDevice.exposureMode = exposureMode;
            }
            else {
                NSLog( @"Exposure mode %@ is not supported. Exposure mode is %@.", [self stringFromExposureMode:exposureMode], [self stringFromExposureMode:self.videoDevice.exposureMode] );
            }
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeExposureDuration:(float)exposureDuration
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        double p = pow( exposureDuration, kExposureDurationPower ); // Apply power function to expand slider's low-end range
        double minDurationSeconds = MAX( CMTimeGetSeconds( self.videoDevice.activeFormat.minExposureDuration ), kExposureMinimumDuration );
        double maxDurationSeconds = CMTimeGetSeconds( self.videoDevice.activeFormat.maxExposureDuration );
        double newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
        
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            [self.videoDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds( newDurationSeconds, 1000*1000*1000 )  ISO:AVCaptureISOCurrent completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeISO:(float)ISO
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        // 参数合法性校验
        if(ISO < self.videoDevice.activeFormat.minISO || ISO > self.videoDevice.activeFormat.maxISO) {
            return;
        }
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            [self.videoDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:ISO completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeExposureTargetBias:(float)exposureTargetBias
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        // 参数合法性校验
        if(exposureTargetBias < self.videoDevice.minExposureTargetBias || exposureTargetBias > self.videoDevice.maxExposureTargetBias) {
            return;
        }
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            [self.videoDevice setExposureTargetBias:exposureTargetBias completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            if ( [self.videoDevice isWhiteBalanceModeSupported:whiteBalanceMode] ) {
                self.videoDevice.whiteBalanceMode = whiteBalanceMode;
            }
            else {
                NSLog( @"White balance mode %@ is not supported. White balance mode is %@.", [self stringFromWhiteBalanceMode:whiteBalanceMode], [self stringFromWhiteBalanceMode:self.videoDevice.whiteBalanceMode] );
            }
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)gains
{
    runAsynchronouslyOnQueue(self.sessionQueue, SessionQueueKey, ^{
        NSError *error = nil;
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            // normalizedGains 方法会将值限制在合法范围内
            AVCaptureWhiteBalanceGains normalizedGains = [self normalizedGains:gains]; // Conversion can yield out-of-bound values, cap to limits
            [self.videoDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:normalizedGains completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    });
}

- (void)changeTemperatureAndTint:(float)temperature tint:(float)tint
{
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .temperature = temperature,
        .tint = tint,
    };
    [self setWhiteBalanceGains:[self.videoDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint]];
}

- (void)lockWithGrayWorld
{
    [self setWhiteBalanceGains:self.videoDevice.grayWorldDeviceWhiteBalanceGains];
}

- (AVCaptureWhiteBalanceGains)normalizedGains:(AVCaptureWhiteBalanceGains)gains
{
    AVCaptureWhiteBalanceGains g = gains;
    
    g.redGain = MAX( 1.0, g.redGain );
    g.greenGain = MAX( 1.0, g.greenGain );
    g.blueGain = MAX( 1.0, g.blueGain );
    
    g.redGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.redGain );
    g.greenGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.greenGain );
    g.blueGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.blueGain );
    
    return g;
}

#pragma mark - Utilities

- (void)checkAuthorizationStatus:(NSString *)mediaType {
    BOOL isCheckMicrophoneAuthorizationStatus = [mediaType isEqualToString:AVMediaTypeAudio];
    // Check video authorization status. Video access is required and audio access is optional.
    // If audio access is denied, audio is not recorded during movie recording.
    switch ( [AVCaptureDevice authorizationStatusForMediaType:mediaType] ) {
        case AVAuthorizationStatusAuthorized:
        {
            // The user has previously granted access to the camera
            // Check audio authorization status
            if ( isCheckMicrophoneAuthorizationStatus) {
                [self checkAuthorizationStatus:AVMediaTypeVideo];
            }
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            // The user has not yet been presented with the option to grant video access.
            // We suspend the session queue to delay session running until the access request has completed.
            // Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput for audio during session setup.
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = isCheckMicrophoneAuthorizationStatus ? TBMCameraSetupResultMicrophoneNotAuthorized : TBMCameraSetupResultCameraNotAuthorized;
                    [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
                }
                // Check video authorization status
                if ( isCheckMicrophoneAuthorizationStatus) {
                    [self checkAuthorizationStatus:AVMediaTypeVideo];
                }
                dispatch_resume( self.sessionQueue );
            }];
            break;
        }
        default:
        {
            // The user has previously denied access
            self.setupResult = isCheckMicrophoneAuthorizationStatus ? TBMCameraSetupResultMicrophoneNotAuthorized : TBMCameraSetupResultCameraNotAuthorized;
            [self tbmCameraDidSetupNotify:self setupResult:self.setupResult];
            break;
        }
    }
}

- (NSString *)stringFromFocusMode:(AVCaptureFocusMode)focusMode {
    NSString *string = @"INVALID FOCUS MODE";
    
    if ( focusMode == AVCaptureFocusModeLocked ) {
        string = @"Locked";
    }
    else if ( focusMode == AVCaptureFocusModeAutoFocus ) {
        string = @"Auto";
    }
    else if ( focusMode == AVCaptureFocusModeContinuousAutoFocus ) {
        string = @"ContinuousAuto";
    }
    
    return string;
}

- (NSString *)stringFromExposureMode:(AVCaptureExposureMode)exposureMode {
    NSString *string = @"INVALID EXPOSURE MODE";
    
    if ( exposureMode == AVCaptureExposureModeLocked ) {
        string = @"Locked";
    }
    else if ( exposureMode == AVCaptureExposureModeAutoExpose ) {
        string = @"Auto";
    }
    else if ( exposureMode == AVCaptureExposureModeContinuousAutoExposure ) {
        string = @"ContinuousAuto";
    }
    else if ( exposureMode == AVCaptureExposureModeCustom ) {
        string = @"Custom";
    }
    
    return string;
}

- (NSString *)stringFromWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
    NSString *string = @"INVALID WHITE BALANCE MODE";
    
    if ( whiteBalanceMode == AVCaptureWhiteBalanceModeLocked ) {
        string = @"Locked";
    }
    else if ( whiteBalanceMode == AVCaptureWhiteBalanceModeAutoWhiteBalance ) {
        string = @"Auto";
    }
    else if ( whiteBalanceMode == AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance ) {
        string = @"ContinuousAuto";
    }
    
    return string;
}

void runSynchronouslyOnMainQueue(void (^block)(void)) {
    if ([NSThread isMainThread] ) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

void runAsynchronouslyOnMainQueue(void (^block)(void)) {
    if ([NSThread isMainThread] ) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void runSynchronouslyOnQueue(dispatch_queue_t queue, const void *key, void (^block)(void))
{
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == queue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific(key))
#endif
        {
            block();
        }
        else {
            dispatch_sync(queue, block);
        }
}

void runAsynchronouslyOnQueue(dispatch_queue_t queue, const void *key, void (^block)(void))
{
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == queue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific(key))
#endif
        {
            block();
        }
        else {
            dispatch_async(queue, block);
        }
}

@end
