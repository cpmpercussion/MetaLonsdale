//
//  MetatoneTouchView.m
//  Metatone
//
//  Created by Charles Martin on 17/04/13.
//  Copyright (c) 2013 Charles Martin. All rights reserved.
//

#import "MetatoneTouchView.h"
#import <QuartzCore/QuartzCore.h>

@interface MetatoneTouchView()

@property (strong, nonatomic) UIImage *lastFrame;
@property (strong, nonatomic) CALayer *animationLayer;
@property (strong, nonatomic) UIColor *touchColour;
@property (strong, nonatomic) UIColor *loopColour;
@property (strong, nonatomic) NSString *deviceID;

@end

@implementation MetatoneTouchView

- (NSMutableArray *) touchCirclePoints {
    if (!_touchCirclePoints) _touchCirclePoints = [[NSMutableArray alloc] init];
    return _touchCirclePoints;
}

- (NSMutableArray *)noteCirclePoints {
    if (!_noteCirclePoints) _noteCirclePoints = [[NSMutableArray alloc] init];
    return _noteCirclePoints;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        
        self.deviceID = [[UIDevice currentDevice].identifierForVendor UUIDString];
        NSLog(self.deviceID);
        // Processing Colour codes.
        if ([self.deviceID isEqual:@"1D7BCDC1-5AAB-441B-9C92-C3F00B6FF930"]) {
            //fill(224,23,26);
            self.touchColour = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.8];
        } else if ([self.deviceID isEqual:@"6769FE40-5F64-455B-82D4-814E26986A99"]) {
            //fill(23,27,224);
            self.touchColour = [UIColor colorWithRed:0.1 green:0.1 blue:0.9 alpha:0.8];

        } else if ([self.deviceID isEqual:@"2678456D-9AE7-4DCC-A561-688A4766C325"]) {
            //fill(23,224,105);
            self.touchColour = [UIColor colorWithRed:0.1 green:0.9 blue:0.4 alpha:0.8];

        } else if ([self.deviceID isEqual:@"97F37307-2A95-4796-BAC9-935BF417AC42"]) {
            //fill(224,204,23);
            self.touchColour = [UIColor colorWithRed:0.9 green:0.8 blue:0.1 alpha:0.8];
        } else {
            //fill(255);
            self.touchColour = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.8];
        }
        
        self.loopColour = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8];
        //
        
        self.movingTouchCircleLayer = [self makeCircleLayerWithColour:self.touchColour];
        [self.layer addSublayer:self.movingTouchCircleLayer];
        self.movingTouchCircleLayer.hidden = YES;
    }
    
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        
        self.deviceID = [[UIDevice currentDevice].identifierForVendor UUIDString];
        NSLog(self.deviceID);
        // Processing Colour codes.
        if ([self.deviceID isEqual:@"1D7BCDC1-5AAB-441B-9C92-C3F00B6FF930"]) {
            //fill(224,23,26);
            self.touchColour = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.8];
        } else if ([self.deviceID isEqual:@"6769FE40-5F64-455B-82D4-814E26986A99"]) {
            //fill(23,27,224);
            self.touchColour = [UIColor colorWithRed:0.1 green:0.1 blue:0.9 alpha:0.8];
        } else if ([self.deviceID isEqual:@"2678456D-9AE7-4DCC-A561-688A4766C325"]) {
            //fill(23,224,105);
            self.touchColour = [UIColor colorWithRed:0.1 green:0.9 blue:0.4 alpha:0.8];
        } else if ([self.deviceID isEqual:@"97F37307-2A95-4796-BAC9-935BF417AC42"]) {
            //fill(224,204,23);
            self.touchColour = [UIColor colorWithRed:0.9 green:0.8 blue:0.1 alpha:0.8];
        } else {
            //fill(255);
            self.touchColour = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.8];
        }
        self.loopColour = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8];
        //

        // init code.
        self.movingTouchCircleLayer = [self makeCircleLayerWithColour:self.touchColour];
        [self.layer addSublayer:self.movingTouchCircleLayer];
        self.movingTouchCircleLayer.hidden = YES;
    }
    return self;
}

-(void) drawTouchCircleAt:(CGPoint) point {
    CALayer *layer = [self makeCircleLayerWithColour:self.touchColour];
    [self.touchCirclePoints addObject:layer];
    
    [CATransaction setAnimationDuration:0.0];
    layer.position = point;
    layer.hidden = NO;
    [CATransaction setCompletionBlock:^{
        [CATransaction setAnimationDuration:2.0];
        layer.hidden = YES;
        [CATransaction setCompletionBlock:^{
            [self.touchCirclePoints removeObject:layer];
        }];
    }];    
}


-(void) drawNoteCircleAt:(CGPoint) point {
    CALayer *layer = [self makeCircleLayerWithColour:self.loopColour];
    
    [self.noteCirclePoints addObject:layer];
    
    [CATransaction setAnimationDuration:0.0];
    layer.position = point;
    layer.hidden = NO;
    [CATransaction setCompletionBlock:^{
        [CATransaction setAnimationDuration:2.0];
        layer.hidden = YES;
        [CATransaction setCompletionBlock:^{
            [self.noteCirclePoints removeObject:layer];
        }];
    }];
}

-(CALayer *) makeCircleLayerWithColour:(UIColor *) colour {
    CALayer *layer = [[CALayer alloc] init];
    
    layer.backgroundColor = colour.CGColor;
    layer.shadowOffset = CGSizeMake(0, 3);
    layer.shadowRadius = 5.0;
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.8;
    layer.frame = CGRectMake(0, 0, 50, 50);
    layer.cornerRadius = 25.0;
    [self.layer addSublayer:layer];
    layer.hidden = YES;
    
    return layer;
}

-(void) drawMovingTouchCircleAt:(CGPoint)point {
    [CATransaction setAnimationDuration:0.0];
    self.movingTouchCircleLayer.position = point;
    self.movingTouchCircleLayer.hidden = NO;
}

-(void) hideMovingTouchCircle {
    [CATransaction setAnimationDuration:1.0];
    self.movingTouchCircleLayer.hidden = YES;
}

@end
