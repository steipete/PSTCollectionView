//
//  AppDelegate.h
//  BasicExample
//
//  Created by Indragie Karunaratne on 2012-12-06.
//  Copyright (c) 2012 Indragie Karunaratne. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "INDCollectionView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, INDCollectionViewDataSource, INDCollectionViewDelegate>

@property (assign) IBOutlet NSWindow *window;

@end
