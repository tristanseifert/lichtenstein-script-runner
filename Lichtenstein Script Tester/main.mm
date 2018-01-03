//
//  main.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <glog/logging.h>

int main(int argc, const char * argv[]) {
	// set up logging
	FLAGS_logtostderr = 1;
	FLAGS_colorlogtostderr = 1;
	
	google::InitGoogleLogging(argv[0]);
	google::InstallFailureSignalHandler();
	
	// set up cocoalumberjack
	[DDLog addLogger:[DDOSLogger sharedInstance]];
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
	fileLogger.rollingFrequency = (60 * 60 * 24) * 7;
	[DDLog addLogger:fileLogger];
	
	return NSApplicationMain(argc, argv);
}
