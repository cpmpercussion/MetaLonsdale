//
//  MetatoneViewController.m
//  Metatone
//
//  Created by Charles Martin on 7/04/13.
//  Copyright (c) 2013 Charles Martin. All rights reserved.
//

#import "MetatoneViewController.h"
#import "MetatoneTouchView.h"
#import "ScaleMaker.h"
#include <stdlib.h>

#define TAP_MODE_FIELDS 0
#define TAP_MODE_MELODY 1
#define TAP_MODE_BOTH 2
#define LOOP_TIME 5000

#define SCALE_MODE_F_MIXO 0
#define SCALE_MODE_FSHARP_LYD 1
#define SCALE_MODE_C_LYDSHARP 2
#define METATONE_SCALE_MESSAGE @"SCALE"

#define METATONE_SWITCH_MESSAGE @"SWITCH"
#define METATONE_FIELDS_MESSAGE @"AUTOFIELDS"
#define METATONE_LOOP_MESSAGE @"LOOP"
#define METATONE_RESET_MESSAGE @"RESET"
#define METATONE_TAPMODE_MESSAGE @"TAPMODE"


//@interface UITouch (Private)
//-(float)_pathMajorRadius;
//@end


@interface MetatoneViewController () {
    NSOperationQueue *queue;
}

@property (strong,nonatomic) PdAudioController *audioController;
@property (strong,nonatomic) MetatoneNetworkManager *networkManager;
@property (strong, nonatomic) CMMotionManager* motionManager;
@property (nonatomic) Boolean oscLogging;
@property (nonatomic) Boolean accelLogging;
@property (weak, nonatomic) IBOutlet UILabel *scaleLabel;

@property (nonatomic) Boolean tapLooping;
@property (weak, nonatomic) IBOutlet UILabel *oscLoggingLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *oscLoggingSpinner;
@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic) NSMutableArray *loopedNotes;
@property (weak, nonatomic) IBOutlet MetatoneTouchView *touchView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (nonatomic) int tapMode;
@property (nonatomic) int scaleMode;
@end

@implementation MetatoneViewController

- (PdAudioController *) audioController
{
    if (!_audioController) _audioController = [[PdAudioController alloc] init];
    return _audioController;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Randomise Sounds each time the app is back in focus
    [PdBase sendBangToReceiver:@"randomiseSounds"];
    
    // Setup Networking
    //[[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"appeared.");
}


void arraysize_setup();

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Setup Pd
    if([self.audioController configurePlaybackWithSampleRate:44100 numberChannels:2 inputEnabled:NO mixingEnabled:YES] != PdAudioOK) {
        NSLog(@"failed to initialise audioController");
    } else {
        NSLog(@"audioController initialised.");
    }
    
    // Load externs
    arraysize_setup();
    
    [PdBase openFile:@"metatone_sounds_ver2.pd" path:[[NSBundle mainBundle] bundlePath]];
    [self.audioController setActive: YES];
    [self.audioController print];
    [PdBase setDelegate:self];
    [PdBase sendBangToReceiver:@"randomiseSounds"];
    
    
    // Setup Logging
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OSCLogging"]) {
        self.oscLogging = YES;
        NSLog(@"Setup Logging.");
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AccelerationLogging"]) {
            self.accelLogging = YES;
        }
    } else {
        [self.oscLoggingLabel setText:@""];
        self.oscLogging = NO;
        NSLog(@"No OSC Logging.");
    }
    [self setupOscLogging];
    
    
    // Setup Accelerometer
    self.motionManager = [[CMMotionManager alloc] init];
    [self.motionManager startDeviceMotionUpdates];
    
    if (self.accelLogging) {
        self.motionManager.accelerometerUpdateInterval = 1.0/100.0;
        if (self.motionManager.accelerometerAvailable) {
            NSLog(@"Accelerometer Available.");
            queue = [NSOperationQueue currentQueue];
            [self.motionManager startAccelerometerUpdatesToQueue:queue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                CMAcceleration acceleration = accelerometerData.acceleration;
                if (self.oscLogging) [self.networkManager sendMessageWithAccelerationX:acceleration.x Y:acceleration.y Z:acceleration.z];
            }];
        }
    }
    
    // Looping Test
    self.tapLooping = YES;
    self.tapMode = 0;
    self.scaleMode = 0;
    [self.scaleLabel setText:@"F Mixo"];
    
    // Setup background image
    int choice = arc4random_uniform(5);
    if (choice == 0) {
        [self.backgroundImage setImage:[UIImage imageNamed:@"canvas.jpg"]];
    } else if (choice == 1) {
        [self.backgroundImage setImage:[UIImage imageNamed:@"LonsdaleTradersFloor.jpg"]];
    } else if (choice == 2) {
        [self.backgroundImage setImage:[UIImage imageNamed:@"LonsdaleTradersWood.jpg"]];
    } else if (choice == 3) {
        [self.backgroundImage setImage:[UIImage imageNamed:@"LonsdaleTradersGrill.jpg"]];
    } else if (choice == 4) {
        [self.backgroundImage setImage:[UIImage imageNamed:@"LonsdaleTradersWall.jpg"]];
    }
}

#pragma mark - Note Methods

-(void)triggerTappedNote:(CGPoint)tapPoint {
    // Send to Pd
    if (self.tapMode == TAP_MODE_FIELDS || self.tapMode == TAP_MODE_FIELDS) {
        [PdBase sendBangToReceiver:@"touch" ]; // makes a small sound
        [PdBase sendFloat:[self calculateDistanceFromCenter:tapPoint]/600 toReceiver:@"tapdistance" ];
    }
    if (self.tapMode == TAP_MODE_MELODY || self.tapMode == TAP_MODE_BOTH) {
        [self sendMidiNoteFromPoint:tapPoint withVelocity:40];
    }
}



-(void)scheduleRecurringTappedNote:(CGPoint)tapPoint {
    // max 100 notes in the loopedNotes array.
    //TODO: make sure looped note array actually contains looped notes currently broken.
    NSLog(@"Scheduling a Looped Note");
    LoopingNote *note = [[LoopingNote alloc] initWithNotePoint:tapPoint LoopTime:LOOP_TIME andDelegate:self];
    if ([self.loopedNotes count] > 100) [self.loopedNotes removeObjectAtIndex:0];
    [self.loopedNotes addObject:note];
    NSLog([note description]);
    NSLog([self.loopedNotes description]);
}

-(void)clearAllLoopedNotes {
    //TODO: make sure all looped notes get disabled, currently broken.
    NSLog(@"Clearing Looped Notes");
    NSLog(@"Number of looped notes: %d", [self.loopedNotes count]);
    for (LoopingNote *note in self.loopedNotes) {
        [note disable];
        NSLog(@"disabled a note");
    }
    [self.loopedNotes removeAllObjects];
}

-(CGFloat)calculateDistanceFromCenter:(CGPoint)touchPoint {
    CGFloat xDist = (touchPoint.x - self.view.center.y);
    CGFloat yDist = (touchPoint.y - self.view.center.x);
    return sqrt((xDist * xDist) + (yDist * yDist));
}

-(void) loopingNotePlayed:(CGPoint)notePoint {
    if (self.tapLooping) [self triggerTappedNote:notePoint];
    if (self.tapLooping) [self.touchView drawNoteCircleAt:notePoint];
}

#pragma mark - Touch

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self.view];
    CGFloat distance = [self calculateDistanceFromCenter:touchPoint] /600;
    
    // Measure Acceleration
    CMDeviceMotion *motion = self.motionManager.deviceMotion;
    int velocity = (int) (ABS(motion.userAcceleration.z * 3000) + 5) % 128;

    // Print touch Area.
    //int area = (int) pow(touch._pathMajorRadius, 2)/4;
    //area = area + 10;
    //  NSLog([NSString stringWithFormat:@"Z Accel: %d, Area: %d", velocity,area]);
    
    // Send to Pd - receiver
    if (self.tapMode == TAP_MODE_FIELDS || self.tapMode == TAP_MODE_FIELDS) {
        [PdBase sendBangToReceiver:@"touch" ]; // makes a small sound
        [PdBase sendFloat:distance toReceiver:@"tapdistance" ];
    }
    
    // Send to Pd as a midi note.
    if (self.tapMode == TAP_MODE_MELODY || self.tapMode == TAP_MODE_BOTH) {
        [self sendMidiNoteFromPoint:touchPoint withVelocity:velocity];
    }
    
    // Logging, Looping and Display.
    if (self.tapLooping) [self scheduleRecurringTappedNote:touchPoint]; // setup looping note
    if (self.oscLogging) [self.networkManager sendMessageWithTouch:touchPoint Velocity:0.0]; // osc logging
    [self.touchView drawTouchCircleAt:touchPoint]; // draw in the view
}



-(void)sendMidiNoteFromPoint:(CGPoint) point withVelocity:(int) vel
{
    CGFloat distance = [self calculateDistanceFromCenter:point]/600;
    // Testing sending a midi message as well.
    int velocity = ((int) 25 + 100 * (point.y / 800));
    velocity = (int) (velocity * 0.2) + (vel * 0.8); // include the tap acceleration measurement.
    int note = (int) (distance * 35);
    
    if (self.scaleMode == SCALE_MODE_F_MIXO) {
        note = [ScaleMaker mixolydian:41 withNote:note];
    } else if (self.scaleMode == SCALE_MODE_FSHARP_LYD) {
        note = [ScaleMaker lydian:42 withNote:note];
    } else if (self.scaleMode == SCALE_MODE_C_LYDSHARP) {
        note = [ScaleMaker lydianSharpFive:36 withNote:note];
    }
    [PdBase sendNoteOn:1 pitch:note velocity:velocity]; // send the note to Pd
}


-(void)touchesMoved:(NSSet *) touches withEvent:(UIEvent *)event
{
    // a moving touch.
    // take distance from center
    // take delta from previous location (proportional to velocity)
    UITouch *touch = [touches anyObject];
    CGFloat xVelocity = [touch locationInView:self.view].x - [touch previousLocationInView:self.view].x;
    CGFloat yVelocity = [touch locationInView:self.view].y - [touch previousLocationInView:self.view].y;
    CGFloat velocity = sqrt((xVelocity * xVelocity) + (yVelocity * yVelocity));
    if (self.oscLogging) [self.networkManager sendMessageWithTouch:[touch locationInView:self.view] Velocity:velocity];
    [self.touchView drawMovingTouchCircleAt:[touch locationInView:self.view]];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.oscLogging) [self.networkManager sendMessageTouchEnded];
    [self.touchView hideMovingTouchCircle];
}

#pragma mark - UI

// Cluster Auto Play Switch
- (IBAction)clustersOn:(UISwitch *)sender {
    if (self.oscLogging) [self.networkManager sendMesssageSwitch:@"clustersOn" On:sender.on];
    float value = (sender.on) ? 1 : 0;
    [PdBase sendFloat:value toReceiver:@"autoBowl"];
}

// Cymbal Auto Play Switch
- (IBAction)cymbalsOn:(UISwitch *)sender {
    if (self.oscLogging) [self.networkManager sendMesssageSwitch:@"cymbalsOn" On:sender.on];
    float value = (sender.on) ? 1 : 0;
    [PdBase sendFloat:value toReceiver:@"autoCymbal"];
}

// Field Recording auto play Switch
- (IBAction)fieldsOn:(UISwitch *)sender {
    if (self.oscLogging) [self.networkManager sendMesssageSwitch:@"fieldsOn" On:sender.on];
    float value = (sender.on) ? 1 : 0;
    [PdBase sendFloat:value toReceiver:@"autoField"];
}


// Loop Control Button
- (IBAction)loopingOn:(UISwitch *)sender {
    if (self.oscLogging) [self.networkManager sendMesssageSwitch:@"loopingOn" On:sender.on];
    self.tapLooping = sender.on;
    if (!sender.on) [self.loopedNotes removeAllObjects];
    if (sender.on) [self.networkManager sendMetatoneMessage:METATONE_LOOP_MESSAGE withState:@"on"];
}

// Reset Sounds Button
- (IBAction)reset:(id)sender {
    if (self.oscLogging) [self.networkManager sendMesssageSwitch:@"resetButton" On:YES];
    [PdBase sendBangToReceiver:@"randomiseSounds"];
    self.tapMode = (self.tapMode + 1) % 3;

    [self.networkManager sendMetatoneMessage:METATONE_RESET_MESSAGE withState:@"reset"];
    [self.networkManager sendMetatoneMessage:METATONE_TAPMODE_MESSAGE
                                   withState:[NSString stringWithFormat:@"%d",self.tapMode]];
    
    if (arc4random_uniform(100)>75) [self randomiseScale];
}

// Scale Button
- (IBAction)changeScale:(UIButton *)sender {
    [self randomiseScale];
}

// Scale Method
- (void)randomiseScale {
    // increment scale mode
    self.scaleMode = (self.scaleMode + 1) % 3;
    // update scale label
    if (self.scaleMode == SCALE_MODE_F_MIXO) [self.scaleLabel setText:@"F Mixo"];
    if (self.scaleMode == SCALE_MODE_C_LYDSHARP) [self.scaleLabel setText:@"C Lyd Sharp 5"];
    if (self.scaleMode == SCALE_MODE_FSHARP_LYD) [self.scaleLabel setText:@"F# Lydian"];
    
    [self.networkManager sendMetatoneMessage:METATONE_SCALE_MESSAGE withState:[NSString stringWithFormat:@"%d", self.scaleMode]];
}


- (IBAction)panGestureRecognized:(UIPanGestureRecognizer *)sender {
    CGFloat xVelocity = [sender velocityInView:self.view].x;
    CGFloat yVelocity = [sender velocityInView:self.view].y;
    CGFloat velocity = sqrt((xVelocity * xVelocity) + (yVelocity * yVelocity));
        
    if ([sender state] == UIGestureRecognizerStateBegan) {
        // send pan began message
        [PdBase sendFloat:velocity toReceiver:@"panstarted"];        
    } else if ([sender state] == UIGestureRecognizerStateChanged) {
        // send normal pan changed message
        [PdBase sendFloat:velocity toReceiver:@"touchvelocity" ];
    } else if (([sender state] == UIGestureRecognizerStateEnded) || ([sender state] == UIGestureRecognizerStateCancelled)) {
        [PdBase sendBangToReceiver:@"touchended" ];
    }
}

#pragma mark - OSC LOGGING

- (void)setupOscLogging
{
    // Search network for metatoneLogging sessions
    // Initialise Network
    self.networkManager = [[MetatoneNetworkManager alloc] initWithDelegate:self shouldOscLog:self.oscLogging];
    
    if (!self.networkManager) {
        self.oscLogging = NO;
        [self.oscLoggingLabel setText:@"OSC Logging: Not Connected"];
        NSLog(@"OSC Logging: Not Connected");
    }
}

-(void)stopOscLogging
{
    // Stop searching for metatoneLogging sessions and metatone sessions
    [self.networkManager stopSearches];
}

- (void) searchingForLoggingServer {
    if (self.oscLogging) {
        // Spin the spinner - write "Searching for Logging Server" in the field
        [self.oscLoggingSpinner startAnimating];
        [self.oscLoggingLabel setText:@"Searching for Logging Server..."];
    }
}

-(void) loggingServerFoundWithAddress:(NSString *)address andPort:(int)port andHostname:(NSString *)hostname {
    // Stop the spinner - update info in the field
    [self.oscLoggingSpinner stopAnimating];
    [self.oscLoggingLabel setText:[NSString stringWithFormat:@"Logging to %@\n %@:%d", hostname, address,port]];
}

-(void) stoppedSearchingForLoggingServer {
    if (self.oscLogging) {
        // stop the spinner - write "Logging Server Not Found" in the field.
        [self.oscLoggingSpinner stopAnimating];
        [self.oscLoggingLabel setText: @"Logging Server Not Found!"];
    }
}

-(void) didReceiveMetatoneMessageFrom:(NSString *)device withName:(NSString *)name andState:(NSString *)state {
    NSLog([NSString stringWithFormat:@"METATONE: Received app message from:%@ with state:%@",device,state]);
    
    if ([name isEqualToString:METATONE_SCALE_MESSAGE]) {
        NSLog(@"METATONE: Scale Message received.");
        self.scaleMode = [state intValue];
        // update scale label
        if (self.scaleMode == SCALE_MODE_F_MIXO) [self.scaleLabel setText:@"F Mixo"];
        if (self.scaleMode == SCALE_MODE_C_LYDSHARP) [self.scaleLabel setText:@"C Lyd Sharp 5"];
        if (self.scaleMode == SCALE_MODE_FSHARP_LYD) [self.scaleLabel setText:@"F# Lydian"];
        
    } else if ([name isEqualToString:METATONE_RESET_MESSAGE]) {
        NSLog(@"METATONE: Reset Message received.");
        if (arc4random_uniform(100) > 80) [PdBase sendBangToReceiver:@"randomiseSounds"];
        
    } else if ([name isEqualToString:METATONE_TAPMODE_MESSAGE]) {
        NSLog(@"METATONE: TapMode Message received.");
        if (arc4random_uniform(100) > 80) self.tapMode = [state intValue];
    } else if ([name isEqualToString:METATONE_LOOP_MESSAGE]) {
        if (arc4random_uniform(100)>75) {
            NSLog(@"METATONE: Loop Message Received and Actioned.");
            self.tapLooping = YES;
            [self.loopSwitch setOn:YES animated:YES];
        }
    }
}

@end
