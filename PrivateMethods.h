

@interface SpringBoard : UIApplication
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
@property(nonatomic, getter=isRingerMuted) BOOL ringerMuted;
@end

@interface BBSettingsGateway : NSObject
- (void)setBehaviorOverrideStatus:(BOOL)enabled;
- (void)setActiveBehaviorOverrideTypesChangeHandler:(void (^)(BOOL))block;
@end

@interface PSListController : UIViewController
- (id)loadSpecifiersFromPlistName:(id)arg1 target:(id)arg2;
- (void)removeSpecifier:(id)arg1 animated:(BOOL)arg2;
- (void)setPreferenceValue:(id)arg1 specifier:(id)arg2;
- (void)removeSpecifierAtIndex:(int)arg1 animated:(BOOL)arg2;
- (void)addSpecifier:(id)arg1 animated:(BOOL)arg2;
@end