// Required
extern "C" BOOL isCapable() {
	return YES;
}

// Required
extern "C" BOOL isEnabled() {
	BOOL ret = NO;
	NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.evancoleman.myvibe.plist"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		ret = YES;
	} else {
		NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:path];
		ret = ([[prefs objectForKey:@"enabled"] boolValue] || [prefs objectForKey:@"enabled"] == nil);
		[prefs release];
	}
	return ret;
}

// Required
extern "C" void setState(BOOL enabled) {
	// Set State!
	NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.evancoleman.myvibe.plist"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSMutableDictionary *prefs = [[NSMutableDictionary alloc] init];
		[prefs setObject:[NSNumber numberWithBool:enabled] forKey:@"enabled"];
		[prefs writeToFile:path atomically:YES];
		[prefs release];
	} else {
		NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
		[prefs setObject:[NSNumber numberWithBool:enabled] forKey:@"enabled"];
		[prefs writeToFile:path atomically:YES];
		[prefs release];
	}
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.evancoleman.myvibe.prefs"), NULL, NULL, TRUE);
}

// Required
// How long the toggle takes to toggle, in seconds.
extern "C" float getDelayTime() {
	return 0.1f;
}

// vim:ft=objc
