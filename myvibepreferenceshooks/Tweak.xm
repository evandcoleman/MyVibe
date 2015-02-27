#define exampleTweakPreferencePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.apple.springboard.plist"]

@interface PSSpecifier : NSObject
- (void)setProperty:(id)arg1 forKey:(id)arg2;
- (id)propertyForKey:(id)key;
- (NSDictionary *)properties;
@end

@interface PSListController : UIViewController {
  NSArray *_specifiers;
}
- (id)loadSpecifiersFromPlistName:(id)arg1 target:(id)arg2;
- (void)removeSpecifier:(id)arg1 animated:(BOOL)arg2;
- (void)setPreferenceValue:(id)arg1 specifier:(id)arg2;
- (void)removeSpecifierAtIndex:(int)arg1 animated:(BOOL)arg2;
- (void)addSpecifier:(id)arg1 animated:(BOOL)arg2;
@end

%hook SoundsPrefController

-(id) readPreferenceValue:(PSSpecifier*)specifier {
  NSDictionary *exampleTweakSettings = [NSDictionary dictionaryWithContentsOfFile:exampleTweakPreferencePath];
  if (!exampleTweakSettings[specifier.properties[@"key"]]) {
    return specifier.properties[@"default"];
  }
  return exampleTweakSettings[specifier.properties[@"key"]];
}
 
-(void) setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
  [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:exampleTweakPreferencePath]];
  [defaults setObject:value forKey:specifier.properties[@"key"]];
  [defaults writeToFile:exampleTweakPreferencePath atomically:YES];
  CFStringRef toPost = (CFStringRef)specifier.properties[@"PostNotification"];
  if(toPost) CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), toPost, NULL, NULL, YES);
}

%end