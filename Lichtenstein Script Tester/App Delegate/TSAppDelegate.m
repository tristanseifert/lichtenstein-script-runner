//
//  AppDelegate.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSAppDelegate.h"
#import "TSScriptRunner.h"

@interface TSAppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property IBOutlet NSTextView *codeTextView;

@property IBOutlet NSButton *runButton;
@property IBOutlet NSButton *singleStepButton;
@property IBOutlet NSButton *compileButton;

@property IBOutlet NSTextField *avgExecutionTimeField;

// output buffer size
@property IBOutlet NSTextField *outputSize;

// script runner
@property TSScriptRunner *script;

// output buffer
@property NSMutableData *outputData;

- (void) disableInputsWhileRunning;
- (void) enableInputsAfterRunning;

- (void) allocateBuffer;

@end

@implementation TSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.script = [TSScriptRunner new];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
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
	[self allocateBuffer];
	[self disableInputsWhileRunning];
	
	// run the script
	[self.script runFrame:self.frameCounter];
	
	// increment frame counter for next execution
	[self willChangeValueForKey:@"frameCounter"];
	self.frameCounter++;
	[self didChangeValueForKey:@"frameCounter"];
	
	[self enableInputsAfterRunning];
}

/**
 * Continuously runs the script at 60fps.
 */
- (IBAction) toggleRun:(id) sender {
	if(self.runButton.state == NSControlStateValueOff) {
		[self enableInputsAfterRunning];
		
		// cancel the timer
	}
	// the button was switched on
	else {
		[self allocateBuffer];
		[self disableInputsWhileRunning];
		
		// run the script
	}
	
}

/**
 * Allocates the buffer and attaches it.
 *
 * @note HACK ALERT: This assumes the HSIPixel is 24 bytes.
 */
- (void) allocateBuffer {
	NSUInteger length = 24 * self.outputSize.integerValue;
	self.outputData = [[NSMutableData alloc] initWithLength:length];
}

/**
 * Disables inputs while the script is running.
 */
- (void) disableInputsWhileRunning {
	self.codeTextView.editable = NO;
	self.outputSize.enabled = NO;
}

/**
 * Re-enables inputs when the script has stopped running.
 */
- (void) enableInputsAfterRunning {
	self.codeTextView.editable = YES;
	self.outputSize.enabled = YES;
}

@end
