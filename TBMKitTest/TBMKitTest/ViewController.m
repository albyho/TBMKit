//
//  ViewController.m
//  TBMKitTest
//
//  Created by alby on 2017/1/16.
//  Copyright © 2017年 alby. All rights reserved.
//

#import "ViewController.h"
@import TBMKit;

@interface ViewController () <TBMCameraDelegate>

@property (nonatomic) TBMCamera *camera;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (IBAction)actionTestTBMCamera:(id)sender {
    self.camera = [[TBMCamera alloc] init];
    self.camera.delegate = self;
    [self.camera setup];
}

#pragma mark TBMCameraDelegate
- (void)tbmCameraSetup:(TBMCamera *)camera setupResult:(TBMCameraSetupResult)setupResult {
    // Main Thread
    NSLog(@"%s %ld", __FUNCTION__, setupResult);
}
- (BOOL)tbmCameraConfigureCaptureOutput:(TBMCamera *)camera {
    NSLog(@"%s", __FUNCTION__);
    return YES;
}

@end
