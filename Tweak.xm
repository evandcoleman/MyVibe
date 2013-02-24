#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>

#define PreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.evancoleman.myvibe.plist"]
#define SpringBoardPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.apple.springboard.plist"]

@interface UIApplication (libstatusbar)
- (void)addStatusBarImageNamed: (NSString*) name removeOnExit: (BOOL) remove;
- (void)addStatusBarImageNamed: (NSString*) name;
- (void)removeStatusBarImageNamed: (NSString*) name;
@end

@interface BBSettingsGateway : NSObject
- (void)setBehaviorOverrideStatus:(BOOL)enabled;
- (void)setActiveBehaviorOverrideTypesChangeHandler:(void (^)(BOOL))block;
@end

@interface SBBulletinSystemStateAdapter : NSObject
+ (id)sharedInstance;
- (BOOL)quietModeEnabled;
@end

static BOOL debug = NO;

static BOOL shouldVibe = YES;
static BOOL shouldSilence = YES;
static BOOL onTable = NO;
static BOOL faceDown = NO;
static BOOL silentVibrateWasOn = NO;
static BOOL ringVibrateWasOn = NO;
static BOOL wasDND = NO;
static float defaultThreshold = 0.93;
static NSDictionary *prefsDict = nil;
static CMMotionManager *myVibeMotionManager = nil;
static NSOperationQueue *myvibeOpQ = nil;
static BBSettingsGateway *bbGateway = nil;


void toggleStatusBarItem(BOOL enabled) {
	if(enabled) {
		if([[prefsDict objectForKey:@"showicon"] boolValue] || [prefsDict objectForKey:@"showicon"] == nil)
			[[UIApplication sharedApplication] addStatusBarImageNamed:@"MyVibeVibrate"]; 
	} else {
		if([[prefsDict objectForKey:@"showicon"] boolValue] || [prefsDict objectForKey:@"showicon"] == nil)
			[[UIApplication sharedApplication] removeStatusBarImageNamed:@"MyVibeVibrate"];
	}
}

void toggleVibrate(BOOL enabled) {
	NSMutableDictionary *springPrefs = [[NSMutableDictionary alloc] initWithContentsOfFile:SpringBoardPreferencesFilePath];
	if(!enabled) {
		silentVibrateWasOn = [[springPrefs objectForKey:@"silent-vibrate"] boolValue];
		ringVibrateWasOn = [[springPrefs objectForKey:@"ring-vibrate"] boolValue];
	}
	[springPrefs setObject:[NSNumber numberWithBool:enabled] forKey:@"silent-vibrate"];
	[springPrefs setObject:[NSNumber numberWithBool:enabled] forKey:@"ring-vibrate"];
	[springPrefs writeToFile:SpringBoardPreferencesFilePath atomically:YES];
	[springPrefs release];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.apple.springboard.silent-vibrate.changed"), NULL, NULL, TRUE);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.apple.springboard.ring-vibrate.changed"), NULL, NULL, TRUE);
}

void startMyVibe() {
    myVibeMotionManager = [[CMMotionManager alloc] init];
    myVibeMotionManager.accelerometerUpdateInterval = 2.0;
	myvibeOpQ = [[NSOperationQueue currentQueue] retain];
    CMAccelerometerHandler accHandler = ^ (CMAccelerometerData *accData, NSError *error) {
	
		BOOL tableVibrate = [[prefsDict objectForKey:@"tablevibrate"] boolValue];
		BOOL upsideDownSilent = [[prefsDict objectForKey:@"upsidedownsilent"] boolValue];

		if(debug) NSLog(@"TABLE VIBRATE: %d",tableVibrate && [[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]);
		if(debug) NSLog(@"FACE DOWN SILENT: %d",upsideDownSilent);
		if(debug) NSLog(@"%f",accData.acceleration.z);
		
		float tableThreshold = [[prefsDict objectForKey:@"sensitivity"] floatValue];
		if([prefsDict objectForKey:@"sensitivity"] == nil) tableThreshold = defaultThreshold;

		if(tableVibrate && [[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]) {
			if(accData.acceleration.z > tableThreshold || accData.acceleration.z < -tableThreshold) {
				if(onTable && shouldVibe) {
					//NO VIBRATE
					shouldVibe = NO;
					toggleVibrate(NO);
					toggleStatusBarItem(YES);
				} else if(!onTable) {
					if(debug) NSLog(@"PLACED ON TABLE: FIRST CHECK");
					onTable = YES;
				}
			} else {
				if(!onTable && !shouldVibe) {
					//VIBRATE
					shouldVibe = YES;
					toggleVibrate(YES);
					toggleStatusBarItem(NO);
				} else if(onTable) {
					if(debug) NSLog(@"REMOVED FROM TABLE: FIRST CHECK");
					onTable = NO;
				}
			}
		} else {
			shouldVibe = YES;
			toggleVibrate(YES);
			toggleStatusBarItem(NO);
			onTable = NO;
		}
		if(upsideDownSilent) {
            if(accData.acceleration.z > tableThreshold) {
				if(faceDown && shouldSilence) {
					//SILENT
					shouldSilence = NO;
					wasDND = [[NSClassFromString(@"SBBulletinSystemStateAdapter") sharedInstance] quietModeEnabled];
					[bbGateway setBehaviorOverrideStatus:YES];
				} else if(!faceDown) {
					if(debug) NSLog(@"FACE DOWN: FIRST CHECK");
					faceDown = YES;
				}
			} else {
				if(!faceDown && !shouldSilence) {
					//NOT SILENT
					shouldSilence = YES;
					[bbGateway setBehaviorOverrideStatus:wasDND];
				} else if(faceDown) {
					if(debug) NSLog(@"FACE UP: FIRST CHECK");
					faceDown = NO;
				}
			}
		} else {
			shouldSilence = YES;
			[bbGateway setBehaviorOverrideStatus:wasDND];
			faceDown = NO;
		}
	};
	[myVibeMotionManager startAccelerometerUpdatesToQueue:myvibeOpQ withHandler:accHandler];
}

static void updatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if(debug) NSLog(@"UPDATE PREFS");
    if(![[NSFileManager defaultManager] fileExistsAtPath:PreferencesFilePath]) {
        NSMutableDictionary *defaultPrefs = [[NSMutableDictionary alloc] init];
        [defaultPrefs setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
        [defaultPrefs setObject:[NSNumber numberWithBool:[[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]] forKey:@"tablevibrate"];
        [defaultPrefs setObject:[NSNumber numberWithBool:NO] forKey:@"upsidedownsilent"];
        [defaultPrefs writeToFile:PreferencesFilePath atomically:YES];
        [defaultPrefs release];
    }
    [prefsDict release];
    prefsDict = [[NSDictionary alloc] initWithContentsOfFile:PreferencesFilePath];
    if([[prefsDict objectForKey:@"enabled"] boolValue] || [prefsDict objectForKey:@"enabled"] == nil) {
        if([[prefsDict objectForKey:@"tablevibrate"] boolValue] || [[prefsDict objectForKey:@"upsidedownsilent"] boolValue] || [prefsDict objectForKey:@"tablevibrate"] == nil) {
            if(myVibeMotionManager == nil) {
                startMyVibe();
            }
        } else {
            if(myVibeMotionManager != nil) {
                [myVibeMotionManager stopAccelerometerUpdates];
                [myVibeMotionManager release];
                myVibeMotionManager = nil;
                [myvibeOpQ release];
                myvibeOpQ = nil;
                onTable = nil;
                faceDown = nil;
                [[UIApplication sharedApplication] removeStatusBarImageNamed:@"MyVibeVibrate"];
            }
        }
    } else {
        if(myVibeMotionManager != nil) {
            [myVibeMotionManager stopAccelerometerUpdates];
            [myVibeMotionManager release];
            myVibeMotionManager = nil;
            [myvibeOpQ release];
            myvibeOpQ = nil;
            onTable = nil;
            faceDown = nil;
            [[UIApplication sharedApplication] removeStatusBarImageNamed:@"MyVibeVibrate"];
        }
    }
}

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, updatePrefs, CFSTR("net.evancoleman.myvibe.prefs"), NULL, CFNotificationSuspensionBehaviorHold);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.evancoleman.myvibe.prefs"), NULL, NULL, TRUE);
	
	bbGateway = [[BBSettingsGateway alloc] init];
}