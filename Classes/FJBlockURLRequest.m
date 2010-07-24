//
//  FJBlockURLRequest.m
//  FJNetworkBlockManager
//
//  Created by Corey Floyd on 7/24/10.
//  Copyright (c) 2010 Flying Jalapeño. All rights reserved.
//

#import "FJBlockURLRequest.h"

//#define USE_CHARLES_PROXY

int const maxAttempts = 3;

@implementation FJBlockURLRequest


@synthesize connectionThread;
@synthesize requestQueue;
@synthesize request;
@synthesize connection;
@synthesize completionQueue;
@synthesize completionBlock;
@synthesize failureBlock;
@synthesize inProcess;
@synthesize attempt;
@synthesize responseData;



- (void) dealloc
{
    
    [responseData release];
    responseData = nil;    
    [request release];
    request = nil;
    [connection release];
    connection = nil;
    Block_release(completionBlock);
    Block_release(failureBlock);
    dispatch_release(completionQueue);  
    dispatch_release(requestQueue);
    [connectionThread release];
    connectionThread = nil; 
    [super dealloc];
}


- (id)initWithRequest:(NSURLRequest*)req
     connectionThread:(NSThread*)thread
      completionQueue:(dispatch_queue_t)queue 
      completionBlock:(FJNetworkResponseHandler)completion
         failureBlock:(FJNetworkErrorHandler)failure{
    
    self = [super init];
    if (self != nil) {
        
        self.connectionThread = thread;
        self.request = req;
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManagerRequest.%i", [self hash]];
        self.requestQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(requestQueue);
        
        
        if(queue == nil)
            queue = dispatch_get_main_queue();
        
        dispatch_retain(queue);
        self.completionQueue = queue;
        self.completionBlock = completion;
        self.failureBlock = failure;
        self.attempt = 0;
        self.inProcess = NO;
    }
    return self;
}

- (void)start{
    
    dispatch_async(self.requestQueue, ^{
        
        if(inProcess){
            return;
        }
        
        self.inProcess = YES;
        [self performSelector:@selector(openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        
        
    });
}

- (void)openConnection{
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        [self performSelector:@selector(openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        return;
    }
    
    
    NSLog(@"sending request...");
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
    
    if(connection){
        
        dispatch_async(self.requestQueue, ^{
            
            self.responseData = [NSMutableData data];
            
        });
        
    }else{
        
		NSLog(@"theConnection is NULL");
	}
    
    
}

#ifdef USE_CHARLES_PROXY

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

#endif


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    dispatch_async(self.requestQueue, ^{
        
        [responseData setLength:0];
        
    });
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    dispatch_async(self.requestQueue, ^{
        
        [responseData appendData:data];
        
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    dispatch_async(self.requestQueue, ^{
        
        NSString *failureMessage = [NSString stringWithFormat:@"Connection failed: %@", [error description]];
        NSLog(@"%@", failureMessage);
        
        self.attempt++;
        
        if(self.attempt > maxAttempts){
            
            self.responseData = nil;
            
            dispatch_async(self.completionQueue, ^{
                
                self.failureBlock(error);
                
                dispatch_async(self.requestQueue, ^{
                    
                    self.inProcess = NO;
                    
                });
                
            });
            
        }else{
            
            [self start];
            
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    dispatch_async(self.completionQueue, ^{
        
        self.completionBlock(self.responseData);
        
        dispatch_async(self.requestQueue, ^{
            
            self.inProcess = NO;
        });
        
    });
}


- (void)cancel{
    
    dispatch_async(self.requestQueue, ^{
        
        [self.connection cancel];
        
        self.responseData = nil;
        
        self.inProcess = NO;
        
    });
}


@end
