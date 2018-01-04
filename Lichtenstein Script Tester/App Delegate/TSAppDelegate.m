//
//  AppDelegate.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSAppDelegate.h"
#import "TSScriptRunner.h"
#import "TSOutputRenderer.h"

#import "TSPropertyKeyView.h"
#import "TSPropertyValueView.h"

#import "NoodleLineNumberView.h"

@interface TSAppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property IBOutlet NSTextView *codeTextView;
@property NoodleLineNumberView *lineNumberView;

@property IBOutlet NSButton *runButton;
@property IBOutlet NSButton *singleStepButton;
@property IBOutlet NSButton *compileButton;

@property IBOutlet TSOutputRenderer *outputRenderer;

// when clear, the script is running
@property BOOL controlsEnabled;

// output buffer size
@property IBOutlet NSTextField *outputSize;

// script runner
@property TSScriptRunner *script;

// output buffer
@property NSMutableData *outputData;

// timer to run the script
@property NSTimer *timer;

// properties to pass to the script
@property NSMutableDictionary *properties;
@property IBOutlet NSTableView *table;

- (void) disableInputsWhileRunning;
- (void) enableInputsAfterRunning;

- (void) allocateBuffer;

- (void) timerCallback;

@end

@implementation TSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.script = [TSScriptRunner new];
	
	[self willChangeValueForKey:@"controlsEnabled"];
	self.controlsEnabled = YES;
	[self didChangeValueForKey:@"controlsEnabled"];
	
	// attempt to load properties from user defaults
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	
	[self willChangeValueForKey:@"properties"];
	
	if([d objectForKey:@"effectProperties"]) {
		self.properties = [[d objectForKey:@"effectProperties"] mutableCopy];
	} else {
		self.properties = [NSMutableDictionary new];
		
		DDLogVerbose(@"Created new effect properties array");
	}
	
	DDLogVerbose(@"Loaded properties: %@", self.properties);
	
	[self didChangeValueForKey:@"properties"];
	
	[self.table reloadData];
	
	// add line number view
	NSScrollView *scrollView = self.codeTextView.enclosingScrollView;
	
	self.lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:scrollView];
	
	scrollView.verticalRulerView = self.lineNumberView;
	scrollView.hasHorizontalRuler = NO;
	scrollView.hasVerticalRuler = YES;
	scrollView.rulersVisible = YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
	
	// save properties
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject:self.properties forKey:@"effectProperties"];
	
	DDLogVerbose(@"Saved properties: %@", self.properties);
	
	// de-allocate the script engine
	[self.script teardown];
	self.script = nil;
}

/**
 * Attempts to compile the script.
 */
- (IBAction) compile:(id) sender {
	NSString *code = self.codeTextView.string;
	
	if([self.script compileScript:code]) {
		self.runButton.enabled = YES;
		self.singleStepButton.enabled = YES;
	} else {
		NSAlert *a = [NSAlert new];
		a.messageText = @"Compile Error";
		a.informativeText = @"One or more compile errors occurred. Check the console.";
		
		[a addButtonWithTitle:@"OK"];
		
		[a beginSheetModalForWindow:self.window completionHandler:nil];
		
		self.runButton.enabled = NO;
		self.singleStepButton.enabled = NO;
	}
}

/**
 * Performs a single step through the script.
 */
- (IBAction) singleStep:(id) sender {
	// allocate the output buffer
	[self allocateBuffer];
	
	// disable the input fields
	[self disableInputsWhileRunning];
	
	self.runButton.enabled = NO;
	
	// copy properties
	[self.script setParams:[self.properties copy]];
	
	// run the script
	[self.script runFrame:self.frameCounter];
	
	// increment frame counter for next execution
	[self willChangeValueForKey:@"frameCounter"];
	self.frameCounter++;
	[self didChangeValueForKey:@"frameCounter"];
	
	[self.outputRenderer setNeedsDisplay:YES];
	
	// re-enable UI
	[self enableInputsAfterRunning];
	
	self.runButton.enabled = YES;
}

/**
 * Continuously runs the script at 60fps.
 */
- (IBAction) toggleRun:(id) sender {
	if(self.runButton.state == NSControlStateValueOff) {
		[self enableInputsAfterRunning];
		
		self.singleStepButton.enabled = YES;
		
		// cancel the timer
		[self.timer invalidate];
	}
	// the button was switched on
	else {
		[self allocateBuffer];
		[self disableInputsWhileRunning];
		
		self.singleStepButton.enabled = NO;
		
		// run the script
		NSTimeInterval timeInterval = 1.0 / 60.0;
		
		self.timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
													   target:self
													 selector:@selector(timerCallback)
													 userInfo:nil
													  repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:self.timer
									 forMode:NSEventTrackingRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:self.timer
									 forMode:NSModalPanelRunLoopMode];
	}
}

/**
 * Timer callback.
 */
- (void) timerCallback {
	// copy properties
	[self.script setParams:[self.properties copy]];
	
	// run the script
	[self.script runFrame:self.frameCounter];
	
	// increment frame counter
	[self willChangeValueForKey:@"frameCounter"];
	self.frameCounter++;
	[self didChangeValueForKey:@"frameCounter"];
	
	[self.outputRenderer setNeedsDisplay:YES];
}

/**
 * Allocates the buffer and attaches it.
 *
 * @note HACK ALERT: This assumes the HSIPixel is 24 bytes.
 */
- (void) allocateBuffer {
	NSUInteger length = 24 * self.outputSize.integerValue;
	self.outputData = [[NSMutableData alloc] initWithLength:length];
	
	self.outputRenderer.dataArray = self.outputData;
	self.outputRenderer.numPixels = self.outputSize.integerValue;
	
	[self.script attachBuffer:self.outputData];
}

/**
 * Disables inputs while the script is running.
 */
- (void) disableInputsWhileRunning {
	[self willChangeValueForKey:@"isScriptRunning"];
	self.controlsEnabled = NO;
	[self didChangeValueForKey:@"isScriptRunning"];
}

/**
 * Re-enables inputs when the script has stopped running.
 */
- (void) enableInputsAfterRunning {
	[self willChangeValueForKey:@"isScriptRunning"];
	self.controlsEnabled = YES;
	[self didChangeValueForKey:@"isScriptRunning"];
}

#pragma mark Table View Stuff
/**
 * Adds a new key to the dictionary.
 */
- (IBAction) addNewKey:(id) sender {
	self.properties[@"New Key"] = @69;
	
	[self.table reloadData];
}

/**
 * Removes the key currently selected.
 */
- (IBAction) removeKey:(id) sender {
	if(self.table.selectedRow != -1) {
		NSUInteger row = self.table.selectedRow;
		NSString *key = self.properties.allKeys[row];
		
		DDLogVerbose(@"Removing key %@", key);
		[self.properties removeObjectForKey:key];
		
		// force table reload
		[self.table reloadData];
	}
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.properties.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
				  row:(NSInteger)row {
	
	// get key and value
	NSString *key = self.properties.allKeys[row];
	NSNumber *value = self.properties[key];
	
	// dequeue a cell
	NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier
														owner:self];
	
	// key column?
	if([tableColumn.identifier isEqualToString:@"key"]) {
		TSPropertyKeyView *keyView = (TSPropertyKeyView *) cell;
		keyView.keyDidChangeCallback = nil;
		
		keyView.keyString = key;
		
		// asisgn callback
		keyView.keyDidChangeCallback = ^(TSPropertyKeyView *view, NSString *oldKey, NSString *newKey) {
			DDLogVerbose(@"Renaming key %@ to %@", oldKey, newKey);
			
			// rename the key
			self.properties[newKey] = self.properties[oldKey];
			[self.properties removeObjectForKey:oldKey];
			
			// remove the callback to avoid us deleting the key
			view.keyDidChangeCallback = nil;
			view.keyString = newKey;
			
			// force a reload with the updated key
			[self.table reloadData];
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self.table reloadData];
			});
		};
	}
	// value column?
	else {
		TSPropertyValueView *valueView = (TSPropertyValueView *) cell;
		valueView.valueDidChangeCallback = nil;
		
		valueView.valueNumber = value;
		valueView.key = key;
		
		valueView.valueDidChangeCallback = ^(TSPropertyValueView *view, NSString *key, NSNumber *newValue) {
			DDLogVerbose(@"Changing value of key %@ to %@", key, newValue);
			
			self.properties[key] = newValue;
		};
	}
	
	return cell;
}


@end
