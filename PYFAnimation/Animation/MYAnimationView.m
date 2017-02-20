//
//  MYAnimationView.m
//  TyunStackDemos
//
//  Created by T_yun on 2017/1/12.
//  Copyright © 2017年 优谱德. All rights reserved.
//

#import "MYAnimationView.h"
#import "AnimOperation.h"



CGFloat const gestureMinimumTranslation = 20.0 ;


typedef enum : NSInteger {
    
    kCameraMoveDirectionNone,
    
    kCameraMoveDirectionUp,
    
    kCameraMoveDirectionDown,
    
    kCameraMoveDirectionRight,
    
    kCameraMoveDirectionLeft
    
} CameraMoveDirection ;


@interface MYAnimationView () <CAAnimationDelegate> {
    

    CIContext *_context;//Core Image上下文
    CIImage *_image;//我们要编辑的图像
    CIImage *_outputImage;//处理后的图像
    
    CIFilter *_colorControlsFilter;//色彩滤镜
    
    CameraMoveDirection direction;
    

    
}

@property(nonatomic) CGFloat brightness NS_AVAILABLE_IOS(5_0);        // 0 .. 1.0, where 1.0 is maximum brightness. Only supported by main screen.

@property (nonatomic, strong) NSMutableArray <UIImageView *>*imagesArray;

@property (nonatomic, assign) CGFloat originY;

@property (nonatomic, assign) CGFloat imageWidth;

@property (nonatomic, assign) BOOL isDrawed;


//用来循环记录 八个动画
@property (nonatomic, assign) NSInteger animationCount;

//计数次数
@property (nonatomic, assign) NSInteger numberCount;

//并行队列
@property (nonatomic, strong) NSOperationQueue *myQueue;

@property (nonatomic, assign) CGFloat imageOriginY;

@end

@implementation MYAnimationView

- (instancetype)initWithOriginY:(CGFloat)originY imageOriginY:(CGFloat)imageOriginY imageWidth:(CGFloat)imageWidth {

    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    if (self = [super initWithFrame:CGRectMake(-imageWidth, originY, screenWidth + imageWidth, screenHeight - originY)]) {
        
        //初始赋值
        self.animationDuration = 0.15;
        self.animationCount = 0;
        
        self.originY = originY;
        self.imageWidth = imageWidth;
        self.imageOriginY = imageOriginY;
        
        
 
        [self initCustomSilder];
        //使用GPU渲染，推荐,但注意GPU的CIContext无法跨应用访问，例如直接在UIImagePickerController的完成方法中调用上下文处理就会自动降级为CPU渲染，所以推荐现在完成方法中保存图像，然后在主程序中调用
        
        _context=[CIContext contextWithOptions:nil];
        
        //取得滤镜
        _colorControlsFilter=[CIFilter filterWithName:@"CIColorControls"];
    }
    
    return self;
}

//创建亮度调节器
- (void)initCustomSilder {
    
    UISlider *brightSlider = [[UISlider alloc] initWithFrame:CGRectMake(self.imageWidth + 20, self.bounds.size.height - 100, [UIScreen mainScreen].bounds.size.width - 40, 80)];
    //亮度滑竿
    brightSlider.minimumValue = 0;
    brightSlider.maximumValue = 1;
    float value = [UIScreen mainScreen].brightness;

    brightSlider.value = value;
    brightSlider.minimumValueImage = [UIImage imageNamed:@"ReduceBright_image"];
    brightSlider.maximumValueImage = [UIImage imageNamed:@"IncreaseBright_image"];
    brightSlider.minimumTrackTintColor = [UIColor whiteColor];
    brightSlider.maximumTrackTintColor = [UIColor colorWithRed:201.0/255 green:99.0/255 blue:49.0/255 alpha:1];
    [brightSlider addTarget:self action:@selector(brightness:) forControlEvents:UIControlEventValueChanged];

    [self addSubview:brightSlider];
    
    
}



- (NSOperationQueue *)myQueue {

    if (_myQueue == nil) {
        
        _myQueue = [[NSOperationQueue alloc] init];
        _myQueue.maxConcurrentOperationCount = 1;
    }
    
    return _myQueue;
}

//只能执行一次
- (void)drawView{
    
    
    
    if (_isDrawed) {
        
        return;
    }
    _isDrawed = YES;

    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat originY = self.imageOriginY;
    CGFloat imageWidth = self.imageWidth;
    //算法
    //贝塞尔公式
    //    CGFloat kScale = (kScreenWidth / 320);
    CGPoint point0 = CGPointMake(0, originY);
    CGPoint point1 = CGPointMake(screenWidth / 2 - 10, originY - 100);
    CGPoint point2 = CGPointMake(screenWidth + imageWidth, originY - 100);
    //iOS坐标系与平面直角坐标系Y轴相反  取point0为平面直角坐标系原点重新构造
    CGPoint rcsPoint0 = CGPointMake(0, 0); //Rectangular coordinate system
    CGPoint rcsPoint1 = CGPointMake(point1.x, point0.y - point1.y);
    CGPoint rcsPoint2 = CGPointMake(point2.x, point0.y - point2.y);
    //二次贝塞尔
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:point0];
    [path addQuadCurveToPoint:point2 controlPoint:point1];
    
    
    CAShapeLayer *pathLayer = [CAShapeLayer layer];
    pathLayer.position = CGPointMake(0, 0);
    pathLayer.lineWidth = 2;
    pathLayer.strokeColor = _curveColor.CGColor;
    pathLayer.fillColor = nil;
    pathLayer.path = path.CGPath;
    [self.layer addSublayer:pathLayer];
    
    //减去圆角
    UIImageView *firstImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, point0.y - imageWidth / 2, imageWidth, imageWidth)];
    CGFloat offsetY = [self getYWithX:imageWidth / 2 point0:rcsPoint0 point1:rcsPoint1 point2:rcsPoint2];
    firstImage.center = CGPointMake(imageWidth / 2, point0.y - offsetY);
    
    
    //添加前五个圆 一个隐藏在最前面
    self.imagesArray = @[].mutableCopy;
    for (CGFloat i = 0; i < 5; i++) {
        UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(imageWidth * i, point0.y - offsetY, imageWidth, imageWidth)];
        //x相邻算上高度差 缝隙太大 后面减一个i
        CGFloat centerX = (imageWidth) * i + imageWidth / 2 - i;
        CGFloat offsetY = [self getYWithX:centerX point0:rcsPoint0 point1:rcsPoint1 point2:rcsPoint2];
        imageView1.center = CGPointMake(centerX, point0.y - offsetY);
        imageView1.contentMode = UIViewContentModeScaleAspectFill;
        imageView1.layer.cornerRadius = 20;
        imageView1.layer.masksToBounds = YES;
        imageView1.image = _beadsImage;
        [self addSubview:imageView1];
        [self.imagesArray addObject:imageView1];
    }
    //添加后面四个圆
    UIImageView *lastView = [[UIImageView alloc] initWithFrame:CGRectMake(point2.x, point2.y - imageWidth / 2, imageWidth, imageWidth)];
    CGFloat lastOffsetY = [self getYWithX:point2.x + imageWidth / 2 point0:point0 point1:point1 point2:point2];
    lastView.center = CGPointMake(point2.x - imageWidth / 2,point0.y - lastOffsetY);
    for (int i = 0; i < 4; i++) {
        
        UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake(point2.x, point2.y - imageWidth / 2, imageWidth, imageWidth)];
        CGFloat centerX = point2.x + (imageWidth / 2) - i * imageWidth - 0.5 * i; //加0.5的缝隙
        if (i != 0) {
            
            CGFloat offsetY = [self getYWithX:centerX point0:rcsPoint0 point1:rcsPoint1 point2:rcsPoint2];
            image.center = CGPointMake(centerX, point0.y - offsetY);
        }
        image.contentMode = UIViewContentModeScaleAspectFill;
        image.layer.cornerRadius = 20;
        image.layer.masksToBounds = YES;
        image.image = _beadsImage;
        [self addSubview:image];
        [self.imagesArray insertObject:image atIndex:5];//后四个按X坐标大小顺序
    }
    
    
    //添加点击事件
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [self addGestureRecognizer:tap];
    
    //添加滑动事件(右滑)
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToRight:)];
    swipe.direction = UISwipeGestureRecognizerDirectionRight;  //向右滑动
    [self addGestureRecognizer:swipe];

    //添加左滑事件
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft; // 向左滑动
    [self addGestureRecognizer:swipeLeft];
    
    //暂时先不用拖动动画需要用到
//    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesutureDetected:)];
//    [self addGestureRecognizer:panGesture];
    
}

//算出曲线上x坐标对应的Y
- (CGFloat)getYWithX:(CGFloat)X point0:(CGPoint)point0 point1:(CGPoint)point1 point2:(CGPoint)point2 {
    
    //B(t) = (1-t^2)*P0 + 2t(1-t)*P1 + t^2*P2
    //Bx = t^2(P2x - P0x - 2P1x) + 2tP1x + P0x
    //解二元一次方程
    CGFloat a, b, c, delt, x1 , x2, t, resultY;
    a = point2.x - point0.x - 2*point1.x; //二次系数
    b = 2 * point1.x; //一次系数
    c = point0.x - X; //0次系数
    
    //当二次系数为0的时候
    if (a == 0) {
        
        t = (X - point0.x) / (2 * point1.x);
        resultY = 2 * t * point1.y + point0.x;
        
        return resultY;
    } else {
        
        delt = b * b - 4 * a * c;
        x1 = (-b + sqrt(delt)) / (2 * a);
        x2 = (-b - sqrt(delt)) / (2 * a);
        
        t = x1 > 0 && x1 < 1 ? x1 : x2; //根的取值范围应在【0，1】
        resultY = (t * t) * (point2.y - point0.y - 2 * point1.y) + 2 * t * point1.y + point0.y;
        
        return resultY;
    }
    
}

//添加拖拽手势可能暂时不要
- (void)panGesutureDetected:(UIPanGestureRecognizer *)sender {
    
    
    CGPoint translation = [sender translationInView: self];
    NSLog(@"凭一句了%f",translation.x);
    if (sender.state == UIGestureRecognizerStateBegan ) {
        
        direction = kCameraMoveDirectionNone;
        
    } else if (sender.state == UIGestureRecognizerStateChanged && direction == kCameraMoveDirectionNone) {
        
        direction = [ self determineCameraDirectionIfNeeded:translation];
        
        // ok, now initiate movement in the direction indicated by the user's gesture
        
        switch (direction) {
                
            case kCameraMoveDirectionDown:
                
                NSLog (@ "Start moving down" );
                
                break ;
                
            case kCameraMoveDirectionUp:
                
                NSLog (@ "Start moving up" );
                
                break ;
                
            case kCameraMoveDirectionRight:
                
                NSLog (@ "Start moving right" );
                
                break ;
                
            case kCameraMoveDirectionLeft:
                
                NSLog (@ "Start moving left" );
                
                break ;
                
            default :
                
                break ;
                
        }
        
    } else if (sender.state == UIGestureRecognizerStateEnded ) {
        
        // now tell the camera to stop
        
        NSLog (@ "Stop" );
        
    }
    

    
    /*
    //创建不可点击区域
    CGRect noResponeseAreFrame = CGRectMake(0, self.bounds.size.height - 100, kScreen_Width + self.imageWidth, 100);
    
    if (CGRectContainsPoint(noResponeseAreFrame, [sender locationInView:self])) {
        NSLog(@"包含");
        
    } else {

        //判断手势
        CGPoint startPoint;
        if (sender.state == UIGestureRecognizerStateBegan) {
            
            startPoint = [sender locationInView:self];
            
        }
        if (sender.state == UIGestureRecognizerStateChanged) {
            
            CGPoint changePoint = [sender velocityInView:self];
            if (startPoint.x > changePoint.x) {
                
            }
            
        }
        if (sender.state == UIGestureRecognizerStateEnded) {
           
            CGPoint endPoint = [sender velocityInView:self];
            BOOL isRight ;
            if (endPoint.x < 0) {
                isRight = NO;
            } else {
                isRight = YES;
            }
            NSLog(@"开始%f,结束%f",startPoint.x,endPoint.x);
            //计数回调
            if (self.countBlock) {
                self.countBlock(isRight);
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(animationDetected:)]) {
                [self.delegate animationDetected:isRight];
            }

            
            AnimOperation *op = [AnimOperation animOperationWithView:self isLeft:!isRight finishedBlock:^(BOOL result) {
                
            }];
            [self.myQueue addOperation:op];

            
        }

    }

    */
}

//点击屏幕
- (void)tapScreen:(UITapGestureRecognizer *)sender {

    
    //创建不可点击区域
    CGRect noResponeseAreFrame = CGRectMake(0, self.bounds.size.height - 100, [UIScreen mainScreen].bounds.size.width + self.imageWidth, 100);
    
    if (CGRectContainsPoint(noResponeseAreFrame, [sender locationInView:self])) {
        NSLog(@"包含");

    } else {
        //计数回调
        if (self.countBlock) {
            
            self.countBlock(YES);
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(animationDetected:)]) {
            [self.delegate animationDetected:YES];
        }
        
        AnimOperation *op = [AnimOperation animOperationWithView:self isLeft:NO finishedBlock:^(BOOL result) {
            
        }];
        
        [self.myQueue addOperation:op];
        NSLog(@"不包含");
    }

//    [self addAnimations];
}

//右滑
- (void)swipeToRight:(UISwipeGestureRecognizer *)sender {
    
    //创建不可点击区域
    CGRect noResponeseAreFrame = CGRectMake(0, self.bounds.size.height - 100, [UIScreen mainScreen].bounds.size.width + self.imageWidth, 100);
    
    if (CGRectContainsPoint(noResponeseAreFrame, [sender locationInView:self])) {
        NSLog(@"包含");
        
    } else {
    
    //计数回调
    if (self.countBlock) {
        
        self.countBlock(YES);
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(animationDetected:)]) {
        [self.delegate animationDetected:YES];
    }
    
    AnimOperation *op = [AnimOperation animOperationWithView:self isLeft:NO finishedBlock:^(BOOL result) {
        
    }];
    
    [self.myQueue addOperation:op];
    }
    //    [self addAnimations];
}

//左滑
- (void)swipeToLeft:(UISwipeGestureRecognizer *)sender {
    //创建不可点击区域
    CGRect noResponeseAreFrame = CGRectMake(0, self.bounds.size.height - 100, [UIScreen mainScreen].bounds.size.width + self.imageWidth, 100);
    
    if (CGRectContainsPoint(noResponeseAreFrame, [sender locationInView:self])) {
        NSLog(@"包含");
        
    } else {
    //计数回调
    if (self.countBlock) {
        
        self.countBlock(NO);
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(animationDetected:)]) {
        [self.delegate animationDetected:NO];
    }
    
    AnimOperation *op = [AnimOperation animOperationWithView:self isLeft:YES finishedBlock:^(BOOL result) {
        
    }];
    
    [self.myQueue addOperation:op];
    }
}

- (void)addAnimationsIsLeft:(BOOL)isLeft {
    
    NSArray *tempArr = @[];
    if (!isLeft) {
        
        tempArr = self.imagesArray.copy;
    } else {
    
        tempArr= [[self.imagesArray reverseObjectEnumerator] allObjects];
    }
    
    for (int index = 0; index < tempArr.count - 1; index++) {
        
        UIImageView *frontImage = tempArr[index];
        UIImageView *backImage = tempArr[index + 1];
        CGPoint point0 = frontImage.center;
        CGPoint point2 = backImage.center;
        CGPoint point1 = CGPointMake((point2.x - point0.x) / 2 - 5 + point0.x, point2.y);
//        NSLog(@"从%f到%f", point0.x, point2.x);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:point0];
        [path addQuadCurveToPoint:point2 controlPoint:point1];
        
        //关键帧动画
        CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        moveAnim.delegate = self;
        moveAnim.path = path.CGPath;
        moveAnim.duration = self.animationDuration;
        //    moveAnim.calculationMode = kCAAnimationCubic;
        moveAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        moveAnim.fillMode = kCAFillModeForwards;
        moveAnim.removedOnCompletion = YES;
        [frontImage.layer addAnimation:moveAnim forKey:nil];
    }
    
}
- (void)animateWithCompleteBlock:(completeBlock)completed isLeft:(BOOL)isLeft {

    [self addAnimationsIsLeft:isLeft];
    self.completeBlock = completed;
 
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {

    if (++self.animationCount % 8 == 0) {
        
        self.animationCount = 0;
        
        if (self.completeBlock) {
            self.completeBlock(YES);
        }
    }

    
}


#pragma mark -- action
- (void)brightness:(UISlider *)sender {
    
//    [_colorControlsFilter setValue:[NSNumber numberWithFloat:sender.value] forKey:@"inputBrightness"];
//    [self setImage];
//    float value = [UIScreen mainScreen].brightness;

    NSLog(@"%lf",sender.value);
    //修改屏幕亮度
    [[UIScreen mainScreen] setBrightness:sender.value];
    
    
}
#pragma mark 将输出图片设置到UIImageView

-(void)setImage{
    
//    输入图片
    CIImage *outputImage= [_colorControlsFilter outputImage];//取得输出图像
    
    CGImageRef temp=[_context createCGImage:outputImage fromRect:[outputImage extent]];
    
    _beadsImage = [UIImage imageWithCGImage:temp];//转化为CGImage显示在界面中
    //如果图片数组已存在需要处理
    if (self.imagesArray) {
        [self.imagesArray enumerateObjectsUsingBlock:^(UIImageView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj setImage:_beadsImage];
        }];
    }
    
    CGImageRelease(temp);//释放CGImage对象
    
}

#pragma  mark -- setter


- (void)setBeadsImage:(UIImage *)beadsImage {
    
    _beadsImage = beadsImage;
    //初始化CIImage源图像
    //输入图片
    _image=[CIImage imageWithCGImage:_beadsImage.CGImage];
    [_colorControlsFilter setValue:_image forKey:@"inputImage"];//设置滤镜的输入图片
    
}
- ( CameraMoveDirection )determineCameraDirectionIfNeeded:( CGPoint )translation {
    
    if (direction != kCameraMoveDirectionNone)
        
        return direction;
    
    // determine if horizontal swipe only if you meet some minimum velocity
    
    if (fabs(translation.x) > gestureMinimumTranslation)
        
    {
        
        BOOL gestureHorizontal = NO;
        
        if (translation.y == 0.0 )
            
            gestureHorizontal = YES;
        
        else
            
            gestureHorizontal = (fabs(translation.x / translation.y) > 5.0 );
        
        if (gestureHorizontal)
            
        {
            
            if (translation.x > 0.0 )
                
                return kCameraMoveDirectionRight;
            
            else
                
                return kCameraMoveDirectionLeft;
            
        }
        
    }
    
    // determine if vertical swipe only if you meet some minimum velocity
    
    else if (fabs(translation.y) > gestureMinimumTranslation)
        
    {
        
        BOOL gestureVertical = NO;
        
        if (translation.x == 0.0 )
            
            gestureVertical = YES;
        
        else
            
            gestureVertical = (fabs(translation.y / translation.x) > 5.0 );
        
        if (gestureVertical)
            
        {
            
            if (translation.y > 0.0 )
                
                return kCameraMoveDirectionDown;
            else
                
                return kCameraMoveDirectionUp;
        }
    }
    return direction;
    
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
