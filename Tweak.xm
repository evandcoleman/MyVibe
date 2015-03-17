#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>

#define PreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.evancoleman.myvibe.plist"]
#define LogFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/myvibe.log"]
//#define SpringBoardPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.apple.springboard.plist"]

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

@interface SBBulletinSoundController : NSObject
+ (id)sharedInstance;
- (BOOL)quietModeEnabled;
@end

static BOOL debug = YES;

static BOOL shouldVibe = YES;
static BOOL shouldSilence = YES;
static BOOL onTable = NO;
static BOOL faceDown = NO;
//static BOOL silentVibrateWasOn = NO;
//static BOOL ringVibrateWasOn = NO;
static BOOL wasDND = NO;
static float defaultThreshold = 0.95;
static float defaultRefresh = 2.0;
static NSMutableDictionary *prefsDict = nil;
static CMMotionManager *myVibeMotionManager = nil;
static NSOperationQueue *myvibeOpQ = nil;
static BBSettingsGateway *bbGateway = nil;

void MVLog(NSString *s, ...) {
  if (!debug) return;
  va_list args;
    va_start(args, s);
    NSString *logString = [[NSString alloc] initWithFormat:s arguments:args];
  NSLog(@"%@", logString);
//  NSFileHandle *filePath = [NSFileHandle fileHandleForWritingAtPath:LogFilePath];
//    if(filePath == nil) {
//        [[NSFileManager defaultManager] createFileAtPath:LogFilePath contents:nil attributes:nil];
//        filePath = [NSFileHandle fileHandleForWritingAtPath:LogFilePath];
//    }
//  NSString *timeStamp = [[NSDate date] description];
//  timeStamp = [timeStamp stringByAppendingString:@": "];
//  NSString *writeString = [timeStamp stringByAppendingString:logString];
//  writeString = [writeString stringByAppendingString:@"\n"];
//    [filePath seekToEndOfFile];
//    [filePath writeData:[writeString dataUsingEncoding:NSUTF8StringEncoding]];
//    [filePath closeFile];
}

%hook SBSoundPreferences

+ (BOOL)shouldVibrateForCurrentRingerState {
	BOOL retVal = NO;
	if(shouldVibe) {
		retVal = %orig;
	}
	return retVal;
}

%end

%hook BBSettingsGateway

- (void)setBehaviorOverrideStatus:(BOOL)arg1 {
	if (self != bbGateway) {
    MVLog(@"SET BEHAVIOR OVERRIDE STATUS: %d", arg1);
		wasDND = arg1;
	}
	%orig;
}

- (void)setBehaviorOverrideStatus:(int)arg1 source:(unsigned)arg2 {
  if (self != bbGateway) {
    MVLog(@"SET BEHAVIOR OVERRIDE STATUS AND SOURCE: %d", arg1);
    wasDND = arg1;
  }
  %orig;
}

%end

/*%hook SBUserAgent

- (void)playRingtoneAtPath:(id)arg1 vibrationPattern:(id)arg2 {
	MVLog(@"VIBRATE: %d",shouldVibe);
	if(shouldVibe) {
		%orig;
	} else {
		%orig(arg1, nil);
	}
}

%end*/

/*%hook AVController

- (BOOL)vibrationEnabled {
	MVLog(@"VIBRATE: %d",shouldVibe);
	return shouldVibe;
}

%end*/

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
	if(!enabled) {
		//silentVibrateWasOn = [[springPrefs objectForKey:@"silent-vibrate"] boolValue];
		//ringVibrateWasOn = [[springPrefs objectForKey:@"ring-vibrate"] boolValue];

		BOOL silentV, ringV;
		CFPropertyListRef svBoolean = CFPreferencesCopyAppValue(CFSTR("silent-vibrate"), CFSTR("com.apple.springboard"));
		if (svBoolean && CFGetTypeID(svBoolean) == CFBooleanGetTypeID())
		    silentV = CFBooleanGetValue((CFBooleanRef)svBoolean)? YES : NO;
		else
		    silentV = YES;

		if (svBoolean)
		    CFRelease(svBoolean);

		CFPropertyListRef rvBoolean = CFPreferencesCopyAppValue(CFSTR("ring-vibrate"), CFSTR("com.apple.springboard"));
		if (rvBoolean && CFGetTypeID(rvBoolean) == CFBooleanGetTypeID())
		    ringV = CFBooleanGetValue((CFBooleanRef)rvBoolean)? YES : NO;
		else
		    ringV = YES;

		if (rvBoolean)
		    CFRelease(rvBoolean);

		[prefsDict setObject:[NSNumber numberWithBool:silentV] forKey:@"silent-vibrate"];
		[prefsDict setObject:[NSNumber numberWithBool:ringV] forKey:@"ring-vibrate"];
		[prefsDict writeToFile:PreferencesFilePath atomically:YES];
		CFPreferencesSetAppValue(CFSTR("silent-vibrate"), kCFBooleanFalse, CFSTR("com.apple.springboard"));
		CFPreferencesSetAppValue(CFSTR("ring-vibrate"), kCFBooleanFalse, CFSTR("com.apple.springboard"));
	} else {
		if([prefsDict objectForKey:@"silent-vibrate"] != nil && [prefsDict objectForKey:@"ring-vibrate"] != nil) {
			MVLog(@"RESTORING TO STATE %@ and %@",[prefsDict objectForKey:@"silent-vibrate"],[prefsDict objectForKey:@"ring-vibrate"]);
			BOOL shouldSV = [[prefsDict objectForKey:@"silent-vibrate"] boolValue];
			BOOL shouldRV = [[prefsDict objectForKey:@"ring-vibrate"] boolValue];
			CFPreferencesSetAppValue(CFSTR("silent-vibrate"), shouldSV? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.apple.springboard"));
			CFPreferencesSetAppValue(CFSTR("ring-vibrate"), shouldRV? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.apple.springboard"));
		}
	}
	CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.apple.springboard.silent-vibrate.changed"), NULL, NULL, TRUE);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.apple.springboard.ring-vibrate.changed"), NULL, NULL, TRUE);
}

void startMyVibe() {
    myVibeMotionManager = [[CMMotionManager alloc] init];
	float refreshRate = [[prefsDict objectForKey:@"refresh"] floatValue];
	if([prefsDict objectForKey:@"refresh"] == nil) refreshRate = defaultRefresh;
    myVibeMotionManager.accelerometerUpdateInterval = refreshRate;
	myvibeOpQ = [[NSOperationQueue currentQueue] retain];
    CMAccelerometerHandler accHandler = ^ (CMAccelerometerData *accData, NSError *error) {

		float refreshRate = [[prefsDict objectForKey:@"refresh"] floatValue];
		if([prefsDict objectForKey:@"refresh"] == nil) refreshRate = defaultRefresh;
		myVibeMotionManager.accelerometerUpdateInterval = refreshRate;

		BOOL tableVibrate = [[prefsDict objectForKey:@"tablevibrate"] boolValue];
		BOOL upsideDownSilent = [[prefsDict objectForKey:@"upsidedownsilent"] boolValue];

		BOOL disableWhileMuted = [[prefsDict objectForKey:@"silentdisable"] boolValue];
		if(disableWhileMuted) {
			int muted = MSHookIvar<int>([UIApplication sharedApplication], "_ringerSwitchState");
			if(muted == 0) {
				tableVibrate = NO;
			}
		}

		float tableThreshold = [[prefsDict objectForKey:@"sensitivity"] floatValue];
		if([prefsDict objectForKey:@"sensitivity"] == nil) tableThreshold = defaultThreshold;

		MVLog(@"TABLE VIBRATE: %d",tableVibrate && [[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]);
		MVLog(@"FACE DOWN SILENT: %d",upsideDownSilent);
		MVLog(@"Reading: %f, Threshold: %f",accData.acceleration.z, tableThreshold);

		if(tableVibrate && [[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]) {
			if(accData.acceleration.z > tableThreshold || accData.acceleration.z < -tableThreshold) {
				if(onTable && shouldVibe) {
					//NO VIBRATE
					shouldVibe = NO;
					toggleVibrate(NO);
					toggleStatusBarItem(YES);
				} else if(!onTable) {
					MVLog(@"PLACED ON TABLE: FIRST CHECK");
					onTable = YES;
				}
			} else {
				if(!onTable && !shouldVibe) {
					//VIBRATE
					shouldVibe = YES;
					toggleVibrate(YES);
					toggleStatusBarItem(NO);
				} else if(onTable) {
					MVLog(@"REMOVED FROM TABLE: FIRST CHECK");
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
					if ([[NSClassFromString(@"SBBulletinSystemStateAdapter") sharedInstance] respondsToSelector:@selector(quietModeEnabled)]) {
						wasDND = [[NSClassFromString(@"SBBulletinSystemStateAdapter") sharedInstance] quietModeEnabled];
					}
					MVLog(@"DND ORIGINAL STATE: %d", wasDND);
					[bbGateway setBehaviorOverrideStatus:YES];
				} else if(!faceDown) {
					MVLog(@"FACE DOWN: FIRST CHECK");
					faceDown = YES;
				}
			} else {
				if(!faceDown && !shouldSilence) {
					//NOT SILENT
					shouldSilence = YES;
					MVLog(@"SETTING DND BACK TO STATE: %d", wasDND);
					[bbGateway setBehaviorOverrideStatus:wasDND];
				} else if(faceDown) {
					MVLog(@"FACE UP: FIRST CHECK");
					faceDown = NO;
				}
			}
		} else {
			shouldSilence = YES;
			//[bbGateway setBehaviorOverrideStatus:wasDND];
			faceDown = NO;
		}
	};
	[myVibeMotionManager startAccelerometerUpdatesToQueue:myvibeOpQ withHandler:accHandler];
}

static void updatePrefs() {
    MVLog(@"UPDATE PREFS");
    if(![[NSFileManager defaultManager] fileExistsAtPath:PreferencesFilePath]) {
        NSMutableDictionary *defaultPrefs = [[NSMutableDictionary alloc] init];
        [defaultPrefs setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
        [defaultPrefs setObject:[NSNumber numberWithBool:[[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]] forKey:@"tablevibrate"];
        [defaultPrefs setObject:[NSNumber numberWithBool:NO] forKey:@"upsidedownsilent"];
        [defaultPrefs writeToFile:PreferencesFilePath atomically:YES];
        [defaultPrefs release];
    }
    [prefsDict release];
    prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:PreferencesFilePath];
	if (![[prefsDict objectForKey:@"showicon"] boolValue]) {
		[[UIApplication sharedApplication] removeStatusBarImageNamed:@"MyVibeVibrate"];
	} else {
		if(onTable && !shouldVibe) {
			[[UIApplication sharedApplication] addStatusBarImageNamed:@"MyVibeVibrate"];
		}
	}

    if([[prefsDict objectForKey:@"enabled"] boolValue] || [prefsDict objectForKey:@"enabled"] == nil) {
        if([[prefsDict objectForKey:@"tablevibrate"] boolValue] || [[prefsDict objectForKey:@"upsidedownsilent"] boolValue] || [prefsDict objectForKey:@"tablevibrate"] == nil) {
            if(myVibeMotionManager == nil) {
				shouldVibe = YES;
				shouldSilence = YES;
				onTable = NO;
				faceDown = NO;
				//silentVibrateWasOn = NO;
				//ringVibrateWasOn = NO;
				wasDND = NO;
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
	updatePrefs();
	toggleVibrate(YES);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updatePrefs, CFSTR("net.evancoleman.myvibe.prefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	//CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.evancoleman.myvibe.prefs"), NULL, NULL, TRUE);

	bbGateway = [[BBSettingsGateway alloc] init];
}