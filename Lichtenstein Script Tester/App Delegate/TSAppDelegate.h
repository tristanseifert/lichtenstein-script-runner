//
//  AppDelegate.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TSAppDelegate : NSObject <NSApplicationDelegate>

- (IBAction) compile:(id) sender;

- (IBAction) singleStep:(id) sender;
- (IBAction) toggleRun:(id) sender;

@property NSUInteger frameCounter;

@end

