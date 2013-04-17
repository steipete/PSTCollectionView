//
//  AppDelegate.m
//  BatchUpdate
//
//  Created by Alex Burgel on 4/17/13.
//
//

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    PSUICollectionViewFlowLayout *layout = [[PSUICollectionViewFlowLayout alloc] init];
    layout.sectionInset = UIEdgeInsetsMake(70, 0, 0, 0);

    self.viewController = [[ViewController alloc] initWithCollectionViewLayout:layout];

    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}


@end
