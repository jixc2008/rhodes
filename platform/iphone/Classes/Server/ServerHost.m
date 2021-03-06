//
//  ServerHost.m
//  Browser
//
//  Created by adam blum on 9/10/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#pragma mark Includes

#include <assert.h>
#include <unistd.h>

#include "rhoruby.h"

#include "defs.h"
#include "Server.h"
#include "HttpContext.h"
#include "ServerHost.h"
#include "Dispatcher.h"
#include "AppManagerI.h"
#include "common/RhoConf.h"
#include "logging/RhoLogConf.h"
#include "sync/syncthread.h"
#include "JSString.h"

#import "logging/RhoLog.h"
#undef DEFAULT_LOGCATEGORY
#define DEFAULT_LOGCATEGORY "ServerHost"

extern char* get_current_location();

#pragma mark -
#pragma mark Constant Definitions

#define kServiceType	CFSTR("_http._tcp.")


#pragma mark -
#pragma mark Static Function Declarations

static void AcceptConnection(ServerRef server, CFSocketNativeHandle sock, CFStreamError* error, void* info);


/* static */ void
AcceptConnection(ServerRef server, CFSocketNativeHandle sock, CFStreamError* error, void* info) {
    
	if (sock == ((CFSocketNativeHandle)(-1))) {
        
		RAWLOG_INFO2("AcceptConnection - Received an error (%d, %d)", (int)error->domain, (int)error->error );
		
		ServerInvalidate(server);
		ServerRelease(server);
		
		CFRunLoopStop(CFRunLoopGetCurrent());
	}
	else {
        
		HttpContextRef http = HttpContextCreate(NULL, sock);
		
		if ((http != NULL) && !HttpContextOpen(http))
			HttpContextRelease(http);
	}
}

#pragma mark -

static ServerHost* sharedSH = nil;

@implementation ServerHost

@synthesize actionTarget, onStartFailure, onStartSuccess, onRefreshView, onNavigateTo, onExecuteJs, onSetViewHomeUrl, onSetViewOptionsUrl, onTakePicture, onChoosePicture;

- (void)serverStarted:(NSString*)data {
	if(actionTarget && [actionTarget respondsToSelector:onStartSuccess]) {
		[actionTarget performSelector:onStartSuccess withObject:data];
	}
	// Do sync w/ remote DB 
	//wake_up_sync_engine();	
}

- (void)serverFailed:(void*)data {
	if(actionTarget && [actionTarget respondsToSelector:onStartFailure]) {
		[actionTarget performSelector:onStartFailure];
	}
}

- (void)refreshView {
	if(actionTarget && [actionTarget respondsToSelector:onRefreshView]) {
		[actionTarget performSelectorOnMainThread:onRefreshView withObject:NULL waitUntilDone:NO];
	}
}

- (void)navigateTo:(NSString*) url {
	if(actionTarget && [actionTarget respondsToSelector:onNavigateTo]) {
		[actionTarget performSelectorOnMainThread:onNavigateTo withObject:url waitUntilDone:NO];
	}
}

- (void)executeJs:(JSString*) js {
	if(actionTarget && [actionTarget respondsToSelector:onExecuteJs]) {
		[actionTarget performSelectorOnMainThread:onExecuteJs withObject:js waitUntilDone:YES];
	}
}

- (void)performRefreshView {
	[self performSelectorOnMainThread:@selector(refreshView)
						   withObject:NULL waitUntilDone:NO]; 
}

- (void)setViewHomeUrl:(NSString*)url {
	if(actionTarget && [actionTarget respondsToSelector:onSetViewHomeUrl]) {
		[actionTarget performSelector:onSetViewHomeUrl withObject:url];
	}	
}

- (void)takePicture:(NSString*) url {
	if(actionTarget && [actionTarget respondsToSelector:onTakePicture]) {
		[actionTarget performSelector:onTakePicture withObject:url];
	}
}

- (void)choosePicture:(NSString*) url {
	if(actionTarget && [actionTarget respondsToSelector:onChoosePicture]) {
		[actionTarget performSelector:onChoosePicture withObject:url];
	}
}

- (void)setViewOptionsUrl:(NSString*)url {
	if(actionTarget && [actionTarget respondsToSelector:onSetViewOptionsUrl]) {
		[actionTarget performSelector:onSetViewOptionsUrl withObject:url];
	}	
}

- (void)ServerHostThreadRoutine:(id)anObject {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	RAWLOG_INFO("Initializing ruby");
	RhoRubyStart();

	char* _url = rho_conf_getString("start_path");
	homeUrl = [NSString stringWithCString:_url encoding:NSUTF8StringEncoding];
	rho_conf_freeString(_url);
	_url = rho_conf_getString("options_path");
	optionsUrl = [NSString stringWithCString:_url encoding:NSUTF8StringEncoding];
	rho_conf_freeString(_url);
	
	RAWLOG_INFO1("Start page: %s", [homeUrl UTF8String]);
	RAWLOG_INFO1("Options page: %s", [optionsUrl UTF8String]);
	[[ServerHost sharedInstance] setViewHomeUrl:homeUrl];
	[[ServerHost sharedInstance] setViewOptionsUrl:optionsUrl];
	
    runLoop = CFRunLoopGetCurrent();
    ServerContext c = {NULL, NULL, NULL, NULL};
    ServerRef server = ServerCreate(NULL, AcceptConnection, &c);
	if (server != NULL && ServerConnect(server, NULL, kServiceType, 8080)) {
		RAWLOG_INFO("HTTP Server started and ready");
		[self performSelectorOnMainThread:@selector(serverStarted:) 
							   withObject:homeUrl waitUntilDone:NO];
		
		RAWLOG_INFO("Create Sync");
		rho_sync_create();
		
        [[NSRunLoop currentRunLoop] run];
        RAWLOG_INFO("Invalidating local server");
        ServerInvalidate(server);
    } else {
        RAWLOG_INFO("Failed to start HTTP Server");
		[self performSelectorOnMainThread:@selector(serverFailed:) 
							   withObject:NULL waitUntilDone:NO];
    }
	
	RAWLOG_INFO("Destroy Sync");
	rho_sync_destroy();
	
	RAWLOG_INFO("Stopping ruby");
	RhoRubyStop();
	
    RAWLOG_INFO("Server host thread routine is completed");
    [pool release];
}
/*
- (int)initializeDatabaseConn {
    NSString *appRoot = [AppManager getApplicationsRootPath];
    NSString *path = [appRoot stringByAppendingPathComponent:@"../db/syncdb.sqlite"];
	return sqlite3_open([path UTF8String], &database);
}*/

extern const char* RhoGetRootPath();

-(void) start {
	//Create 
	appManager = [AppManager instance]; 
	//Configure AppManager
	rho_logconf_Init(RhoGetRootPath());
	[appManager configure];
	//Init log and settings
	
	//Start Sync engine
	//[self initializeDatabaseConn];
	// Startup the sync engine thread
	//start_sync_engine(database);
	
	
	// Start server thread	
    [NSThread detachNewThreadSelector:@selector(ServerHostThreadRoutine:)
                             toTarget:self withObject:nil];
}

-(void) stop {
    CFRunLoopStop(runLoop);
	// Stop the sync engine
	//stop_sync_engine();
	//shutdown_database();
}

- (void)dealloc 
{
    [appManager release];
	[homeUrl release];
	[optionsUrl release];
	[super dealloc];
}

+ (ServerHost *)sharedInstance {
    @synchronized(self) {
        if (sharedSH == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedSH;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedSH == nil) {
            sharedSH = [super allocWithZone:zone];
            return sharedSH;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end

//ruby extension hooks
void webview_refresh() {
	[[ServerHost sharedInstance] refreshView];
}

void webview_navigate(char* url) {
	[[ServerHost sharedInstance] navigateTo:[NSString stringWithCString:url]];
}

char* webview_execute_js(char* js) {
	char * retval;
	JSString *javascript = [[[JSString alloc] init] autorelease];
	javascript.inputJs = [NSString stringWithUTF8String:js];
	[[ServerHost sharedInstance] executeJs:javascript];
	// TBD: Does ruby GC pick this up?
	retval = strdup([[javascript outputJs] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
	return retval;
}

void perform_webview_refresh() {
	[[ServerHost sharedInstance] performRefreshView];														
}

char* webview_current_location() {
	return get_current_location();
}

void take_picture(char* callback_url) {
	[[ServerHost sharedInstance] takePicture:[NSString stringWithCString:callback_url]];		
}

void choose_picture(char* callback_url) {
	[[ServerHost sharedInstance] choosePicture:[NSString stringWithCString:callback_url]];		
}
