//
//  AppDelegate.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "CollectionViewLayout.h"

@interface AppDelegate ()
@property (strong, nonatomic) ViewController *viewController;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[ViewController alloc] initWithCollectionViewLayout:[CollectionViewLayout new]];

    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
