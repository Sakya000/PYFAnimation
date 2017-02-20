//
//  ViewController.m
//  PYFAnimation
//
//  Created by Sakya on 17/2/20.
//  Copyright © 2017年 Sakya. All rights reserved.
//

#import "ViewController.h"
#import "MYAnimationView.h"

@interface ViewController ()<MYAnimationViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //动画模块
    MYAnimationView *myAnimationView = [[MYAnimationView alloc] initWithOriginY:0 imageOriginY:200 imageWidth:40];
    myAnimationView.curveColor = [UIColor colorWithRed:146.0/255 green:147.0/255 blue:152.0/255 alpha:1];
    [myAnimationView setDelegate:self];
    [self.view addSubview:myAnimationView];
    
    myAnimationView.beadsImage  = [UIImage imageNamed:@"@3xf_03"];
    [myAnimationView drawView];

}

- (void)animationDetected:(BOOL)addAnimation {
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
