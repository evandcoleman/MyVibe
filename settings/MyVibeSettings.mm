#import <UIKit/UIKit.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>

#define PreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.evancoleman.myvibe.plist"]

@interface PSSpecifier : NSObject
- (void)setProperty:(id)arg1 forKey:(id)arg2;
- (id)propertyForKey:(id)key;
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

@interface MyVibeListController: PSListController <UIActionSheetDelegate>

@end

@implementation MyVibeListController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"MyVibeSettings" target:self] retain];
		NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PreferencesFilePath];
		if([[prefs objectForKey:@"enabled"] boolValue] || [prefs objectForKey:@"enabled"] == nil) {
			if(![[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]) {
				NSArray *arr = [_specifiers copy];
				for(id a in arr) {
					if([[a identifier] isEqualToString:@"iphone-only"]) {
						[self removeSpecifier:a animated:NO];
					}
				}
				[arr release];
			}
		} else {
			NSMutableArray *temp = [NSMutableArray array];
			[temp addObject:[_specifiers objectAtIndex:0]];
			[temp addObject:[_specifiers lastObject]];
            [_specifiers release];
            _specifiers = [temp copy];
        }
	}
	return _specifiers;
}

- (void)toggleEnabled:(id)value specifier:(id)specifier {
    [self setPreferenceValue:value specifier:specifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if([value boolValue] == YES){
        NSArray *arr = [[self loadSpecifiersFromPlistName:@"MyVibeSettings" target:self] retain];
        [self removeSpecifierAtIndex:2 animated:NO];
        for(unsigned int i = 1;i < [arr count];i++) {
            if([[[UIDevice currentDevice] model] isEqualToString:@"iPhone"] || ![[[arr objectAtIndex:i] identifier] isEqualToString:@"iphone-only"]) {
                [self addSpecifier:[arr objectAtIndex:i] animated:YES];
            }
        }
        [arr release];
    } else {
        NSArray *arr = [_specifiers copy];
        for(unsigned int i = 2;i < ([arr count] - 1);i++) {
                [self removeSpecifier:[arr objectAtIndex:i] animated:YES];
        }
        [arr release];
    }
}

- (void)follow:(id)specifier {
	ACAccountStore *accountStore = [[ACAccountStore alloc] init];

	ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

	[accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
	    if(granted) {
	        NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
	
			if ([accountsArray count] > 1) {
				dispatch_async(dispatch_get_main_queue(), ^{
					UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Which account would you like to use?" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
					for(ACAccount *a in accountsArray) {
						[sheet addButtonWithTitle:[NSString stringWithFormat:@"@%@",a.username]];
					}
					[sheet addButtonWithTitle:@"Cancel"];
					sheet.cancelButtonIndex = [accountsArray count];
					sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
					if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
						PSSpecifier *button = [_specifiers objectAtIndex:_specifiers.count-2];
						CGRect frame = [[button propertyForKey:@"cellObject"] frame];
						[sheet showFromRect:frame inView:self.view animated:YES];
					} else {
						[sheet showInView:self.view];
					}
					[sheet release];
				});
	        } else if([accountsArray count] == 1) {
				ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
				NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
				[tempDict setValue:@"edc1591" forKey:@"screen_name"];
				[tempDict setValue:@"true" forKey:@"follow"];
				SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:@"https://api.twitter.com/1/friendships/create.json"] parameters:tempDict];
				[postRequest setAccount:twitterAccount];
				[postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {

				}];
			}

	    }
	}];
	
	[accountStore release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	ACAccountStore *accountStore = [[ACAccountStore alloc] init];
	ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
	[accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
		if(granted) {
			NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
			if(buttonIndex >= [accountsArray count]) return;
			ACAccount *twitterAccount = [accountsArray objectAtIndex:buttonIndex];
			NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
			[tempDict setValue:@"edc1591" forKey:@"screen_name"];
			[tempDict setValue:@"true" forKey:@"follow"];
			SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:@"https://api.twitter.com/1/friendships/create.json"] parameters:tempDict];
			[postRequest setAccount:twitterAccount];
			[postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
				/*PSSpecifier *button = [_specifiers objectAtIndex:_specifiers.count-2];
				NSLog(@"before %@",[button properties]);
				[[[button propertyForKey:@"cellObject"] titleLabel] setText:@"YES"];
				if(error == nil) {
					[button setProperty:@"Followed!" forKey:@"label"];
				} else {
					[button setProperty:@"An Error Occurred." forKey:@"label"];
				}
				NSLog(@"after %@",[button properties]);*/
			}];
		}
	}];
	[accountStore release];
}

@end
