//
//  AppDelegate.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TSAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource>

- (IBAction) compile:(id) sender;

- (IBAction) singleStep:(id) sender;
- (IBAction) toggleRun:(id) sender;

- (IBAction) addNewKey:(id) sender;
- (IBAction) removeKey:(id) sender;

@property NSUInteger frameCounter;

@end

