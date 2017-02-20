//
//  MYAnimationView.h
//  TyunStackDemos
//
//  Created by T_yun on 2017/1/12.
//  Copyright © 2017年 优谱德. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void(^completeBlock)(BOOL finished);

@protocol MYAnimationViewDelegate <NSObject>

//动画检测
- (void)animationDetected:(BOOL)addAnimation;

@end


@interface MYAnimationView : UIView

//动画完成回调
@property (nonatomic,copy) void(^completeBlock)(BOOL finished);

//计数生效回调
@property (nonatomic, copy) void (^countBlock)(BOOL);

//默认0.15秒
@property (nonatomic, assign) CGFloat animationDuration;

//佛珠图片可以更换的
@property (nonatomic, strong) UIImage *beadsImage;

//曲线颜色
@property (nonatomic, strong) UIColor *curveColor;

//代理
@property (nonatomic, weak) id<MYAnimationViewDelegate>delegate;

//
- (instancetype)initWithOriginY:(CGFloat)originY imageOriginY:(CGFloat)imageOriginY imageWidth:(CGFloat)imageWidth;

- (void)animateWithCompleteBlock:(completeBlock)completed
                          isLeft:(BOOL)isLeft;

- (void)drawView;


@end
