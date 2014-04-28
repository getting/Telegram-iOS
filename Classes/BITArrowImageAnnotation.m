//
//  BITArrowImageAnnotation.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 26.02.14.
//
//

#import "BITArrowImageAnnotation.h"

#define kArrowPointCount 7


@interface BITArrowImageAnnotation()

@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;


@end

@implementation BITArrowImageAnnotation

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.shapeLayer = [CAShapeLayer layer];
    self.shapeLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.shapeLayer.lineWidth = 5;
    self.shapeLayer.fillColor = [UIColor redColor].CGColor;
    
    self.strokeLayer = [CAShapeLayer layer];
    self.strokeLayer.strokeColor = [UIColor redColor].CGColor;
    self.strokeLayer.lineWidth = 10;
    self.strokeLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.strokeLayer];

    [self.layer addSublayer:self.shapeLayer];

    
  }
  return self;
}

- (void)buildShape {
  CGFloat baseWidth = MAX(self.frame.size.width, self.frame.size.height);
  CGFloat topHeight = MAX(baseWidth / 3.0f,10);

  
  CGFloat lineWidth = MAX(baseWidth / 10.0f,3);
  CGFloat startX, startY, endX, endY;
  
  CGRect boundRect = CGRectInset(self.bounds, 0, 0);
  CGFloat arrowLength= sqrt(pow(CGRectGetWidth(boundRect), 2) + pow(CGRectGetHeight(boundRect), 2));
  if (arrowLength < 30){
    
    CGFloat factor = 30.f/arrowLength;
    
    boundRect = CGRectApplyAffineTransform(boundRect, CGAffineTransformMakeScale(factor,factor));
  }
  
  if ( self.movedDelta.width < 0){
    startX = CGRectGetMinX(boundRect);
    endX =  CGRectGetMaxX(boundRect);
  } else {
    startX = CGRectGetMaxX(boundRect);
    endX = CGRectGetMinX(boundRect);

  }
  
  if ( self.movedDelta.height < 0){
    startY = CGRectGetMinY(boundRect);
    endY =  CGRectGetMaxY(boundRect);
  } else {
    startY = CGRectGetMaxY(boundRect);
    endY =  CGRectGetMinY(boundRect);
    
  }
  
  
  if (abs(CGRectGetWidth(boundRect)) < 30 || abs(CGRectGetHeight(boundRect)) < 30){
    CGFloat smallerOne = MIN(abs(CGRectGetHeight(boundRect)), abs(CGRectGetWidth(boundRect)));
    
    CGFloat factor = smallerOne/30.f;
    
    CGRectApplyAffineTransform(boundRect, CGAffineTransformMakeScale(factor,factor));
  }
  
  UIBezierPath *path = [self bezierPathWithArrowFromPoint:CGPointMake(endX, endY) toPoint:CGPointMake(startX, startY) tailWidth:lineWidth headWidth:topHeight headLength:topHeight];
  
  self.shapeLayer.path = path.CGPath;
  self.strokeLayer.path = path.CGPath;
  [CATransaction begin];
  [CATransaction setAnimationDuration:0];
  self.strokeLayer.lineWidth = lineWidth/1.5f;
  self.shapeLayer.lineWidth = lineWidth / 3.0f;

  [CATransaction commit];

}

-(void)layoutSubviews{
  [super layoutSubviews];

  [self buildShape];
  
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (UIBezierPath *)bezierPathWithArrowFromPoint:(CGPoint)startPoint
                                           toPoint:(CGPoint)endPoint
                                         tailWidth:(CGFloat)tailWidth
                                         headWidth:(CGFloat)headWidth
                                        headLength:(CGFloat)headLength {
  CGFloat length = hypotf(endPoint.x - startPoint.x, endPoint.y - startPoint.y);
  
  CGPoint points[kArrowPointCount];
  [self getAxisAlignedArrowPoints:points
                            forLength:length
                            tailWidth:tailWidth
                            headWidth:headWidth
                           headLength:headLength];
  
  CGAffineTransform transform = [self transformForStartPoint:startPoint
                                                        endPoint:endPoint
                                                          length:length];
  
  CGMutablePathRef cgPath = CGPathCreateMutable();
  CGPathAddLines(cgPath, &transform, points, sizeof points / sizeof *points);
  CGPathCloseSubpath(cgPath);
  
  UIBezierPath *uiPath = [UIBezierPath bezierPathWithCGPath:cgPath];
  CGPathRelease(cgPath);
  return uiPath;
}

- (void)getAxisAlignedArrowPoints:(CGPoint[kArrowPointCount])points
                            forLength:(CGFloat)length
                            tailWidth:(CGFloat)tailWidth
                            headWidth:(CGFloat)headWidth
                           headLength:(CGFloat)headLength {
  CGFloat tailLength = length - headLength;
  points[0] = CGPointMake(0, tailWidth / 2);
  points[1] = CGPointMake(tailLength, tailWidth / 2);
  points[2] = CGPointMake(tailLength, headWidth / 2);
  points[3] = CGPointMake(length, 0);
  points[4] = CGPointMake(tailLength, -headWidth / 2);
  points[5] = CGPointMake(tailLength, -tailWidth / 2);
  points[6] = CGPointMake(0, -tailWidth / 2);
}

+ (CGAffineTransform)dqd_transformForStartPoint:(CGPoint)startPoint
                                       endPoint:(CGPoint)endPoint
                                         length:(CGFloat)length {
  CGFloat cosine = (endPoint.x - startPoint.x) / length;
  CGFloat sine = (endPoint.y - startPoint.y) / length;
  return (CGAffineTransform){ cosine, sine, -sine, cosine, startPoint.x, startPoint.y };
}

- (CGAffineTransform)transformForStartPoint:(CGPoint)startPoint
                                       endPoint:(CGPoint)endPoint
                                         length:(CGFloat)length {
  CGFloat cosine = (endPoint.x - startPoint.x) / length;
  CGFloat sine = (endPoint.y - startPoint.y) / length;
  return (CGAffineTransform){ cosine, sine, -sine, cosine, startPoint.x, startPoint.y };
}

#pragma mark - UIView 

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIColor *color = [self colorAtPoint:point];
  CGFloat alpha, white;
  [color getWhite:&white alpha:&alpha];
  if (white || alpha){
    return self;
  } else {
    return nil;
  }

}

#pragma mark - Helpers

// This is taken from http://stackoverflow.com/questions/12770181/how-to-get-the-pixel-color-on-touch
- (UIColor *)colorAtPoint:(CGPoint)point {
  unsigned char pixel[4] = {0};
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixel,
                                               1, 1, 8, 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  
  CGContextTranslateCTM(context, -point.x, -point.y);
  
  [self.layer renderInContext:context];
  
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  UIColor *color = [UIColor colorWithRed:pixel[0]/255.0
                                   green:pixel[1]/255.0 blue:pixel[2]/255.0
                                   alpha:pixel[3]/255.0];
  return color;
}

@end
