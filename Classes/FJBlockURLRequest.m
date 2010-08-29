#import "FJBlockURLRequest.h"
#import "FJBlockURLManager.h"

//#define USE_CHARLES_PROXY

NSString* const FJBlockURLErrorDomain = @"FJBlockURLErrorDomain";

@interface FJBlockURLManager (FJBlockURLRequest)

- (void)scheduleRequest:(FJBlockURLRequest*)req;
- (void)cancelRequest:(FJBlockURLRequest*)req;


@end

int const kMaxAttempts = 3;

@interface FJBlockURLRequest()

@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic, retain) NSURLConnection *connection;

@property (readwrite) BOOL isScheduled; 
@property (readwrite) BOOL inProcess; 
@property (readwrite) BOOL isFinished; 
@property (readwrite) int attempt; 

@property (readwrite) NSUInteger responseCode; 
@property (nonatomic, retain, readwrite) NSMutableData *responseData; 
@property (nonatomic, retain, readwrite) id formattedResponse; 
@property (nonatomic, retain, readwrite) NSHTTPURLResponse* HTTPResponse; 


@property (nonatomic, readwrite) dispatch_queue_t workQueue;
@property (nonatomic, assign, readwrite) FJBlockURLManager *manager; 

- (void)openConnection;

@end

@implementation FJBlockURLRequest

@synthesize manager;
@synthesize connectionThread;
@synthesize workQueue;
@synthesize connection;
@synthesize responseQueue;
@synthesize completionBlock;
@synthesize failureBlock;
@synthesize isScheduled;
@synthesize inProcess;
@synthesize isFinished;
@synthesize attempt;
@synthesize responseData;
@synthesize maxAttempts;
@synthesize headerDelegate;
@synthesize cacheResponse;
@synthesize responseFormatter;
@synthesize formattedResponse;
@synthesize acceptedResponseCodes;
@synthesize responseCode;
@synthesize HTTPResponse;

- (void) dealloc
{
    
    responseFormatter = nil;
    headerDelegate = nil;

    [responseData release];
    responseData = nil;    
    
    [formattedResponse release];
    formattedResponse  = nil;
    
    [connection release];
    connection = nil;
    Block_release(completionBlock);
    Block_release(failureBlock);
    dispatch_release(responseQueue);  
    dispatch_release(workQueue);
    [connectionThread release];
    connectionThread = nil; 
    [super dealloc];
}

- (id)initWithURL:(NSURL*)url{
    
    if ((self = [super initWithURL:url])) {
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManagerRequest.%i", [self hash]];
        self.workQueue = dispatch_queue_create([queueName UTF8String], NULL);
        self.maxAttempts = kMaxAttempts;
        self.responseQueue = dispatch_get_main_queue();
        self.cacheResponse = YES;
        self.acceptedResponseCodes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
        self.responseCode = 0;
        
    }
    return self;    
    
}

- (void)setResponseQueue:(dispatch_queue_t)queue{
    
    if(responseQueue != queue){
        
        dispatch_retain(queue);
        if(responseQueue)
            dispatch_release(responseQueue);
        responseQueue = queue;

    }
}

- (void)setWorkQueue:(dispatch_queue_t)queue{
    
    if(workQueue != queue){
        
        dispatch_retain(queue);
        if(workQueue)
            dispatch_release(workQueue);
        workQueue = queue;
        
    }
}

- (void)schedule{
    
    [self scheduleWithNetworkManager:[FJBlockURLManager defaultManager]];
    
}

- (void)scheduleWithNetworkManager:(FJBlockURLManager*)networkManager{
    
    [headerDelegate setHeaderFieldsForRequest:self];
    
    if(self.manager == nil){
        
        self.manager = networkManager;
    }    
    
    [networkManager scheduleRequest:self];
    
}



- (BOOL)start{
    
    __block BOOL didStart = YES;
    
    dispatch_sync(self.workQueue, ^{
        
        if(inProcess){
            didStart = NO;
            return;
        }
        
        debugLog(@"manager: %@ starting request: %@", [self.manager description], [self description]);

        
        self.inProcess = YES;
        self.attempt = 0;
                
        if(!self.responseQueue){
            
            self.responseQueue = dispatch_get_main_queue();
            
        }
        
        [self performSelector:@selector(openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        
    });
    
    return didStart;
}

- (void)openConnection{
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        [self performSelector:@selector(openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        return;
    }
    
    debugLog(@"opening connection for request: %@", [self description]);
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self delegate:self];
    self.responseData = [NSMutableData data];
    
    if(connection){
        
        dispatch_async(self.workQueue, ^{
            
            self.isFinished = NO;
            
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
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    if([response isKindOfClass:[NSHTTPURLResponse class]]){
        
        self.HTTPResponse = (NSHTTPURLResponse*)response;
        int code = [self.HTTPResponse statusCode];
        self.responseCode = code;
    }
    
    [responseData setLength:0];

    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    [responseData appendData:data];
    
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse{
    
    if(!self.cacheResponse)
        return nil;

    return cachedResponse;
    
}



- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    dispatch_async(self.workQueue, ^{
        
        NSString *failureMessage = [NSString stringWithFormat:@"Connection failed: %@", [error description]];
        NSLog(@"%@", failureMessage);
        
        self.attempt++;
        
        if(self.attempt > self.maxAttempts){
            
            self.responseData = nil;
        
            if(responseQueue && failureBlock){
                
                dispatch_async(self.responseQueue, ^{
                    
                    self.failureBlock(error);
                    
                });
                
            }
            
            self.isFinished = YES;
            self.inProcess = NO;

            
        }else{
            
            [self openConnection];
            
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    __block id response = self.responseData;
    
    //catch unaccepted response codes
    if(![self.acceptedResponseCodes containsIndex:self.responseCode]){
        
        if(self.failureBlock){
         
            dispatch_async(self.responseQueue, ^{
                
                self.failureBlock([NSError invalidNetworkResponseErrorWithStatusCode:self.responseCode URL:[self URL]]);
                
            });
        }
    }else{
        
        if(self.responseFormatter == nil){
            
            if(self.completionBlock){
                
                dispatch_async(self.responseQueue, ^{
                    
                    self.completionBlock(response);
                    
                });
            }
            
        }else if(self.responseFormatter != nil){
            
            __block id val = nil;
            
            if(response != nil && [response length] > 0)
                val = [self.responseFormatter formatResponse:response];
            
            if([val isKindOfClass:[NSError class]]){
                
                if(self.failureBlock){
                    
                    dispatch_async(self.responseQueue, ^{
                        
                        self.failureBlock([NSError nilNetworkRespnseErrorWithURL:[self URL]]);
                        
                    });
                }
            }else{
                
                self.formattedResponse = val;
                
                if(self.completionBlock){
                    
                    dispatch_async(self.responseQueue, ^{
                        
                        self.completionBlock(val);
                        
                    });
                }
            } 
        }
    }
    
        
    dispatch_async(self.workQueue, ^{
        //NSLog(@"Doublecheck: %@", [data description]);
        self.isFinished = YES;
        self.inProcess = NO;
    });
    
    
}


- (void)cancel{
    
    dispatch_async(self.workQueue, ^{
        
        [self.connection performSelector:@selector(cancel) 
                                onThread:self.connectionThread 
                              withObject:nil 
                           waitUntilDone:NO];
        
        [self performSelector:@selector(setResponseData:) 
                     onThread:self.connectionThread 
                   withObject:nil 
                waitUntilDone:NO]; 
        
        
        //we never finished, but are being cancelled we should send the error block
        if(self.isFinished == NO){
            
            NSDictionary* d = [NSDictionary dictionaryWithObject:@"Request was cancelled" forKey:NSLocalizedDescriptionKey];
            
            NSError* error = [NSError errorWithDomain:FJBlockURLErrorDomain code:FJBlockURLErrorCancelled userInfo:d];
            
            if(responseQueue && failureBlock){
                
                dispatch_async(self.responseQueue, ^{
                    
                    self.failureBlock(error);
                    
                });
                
            }
        }
        
        self.isFinished = NO;
        self.inProcess = NO;
        
    });
    
    [self.manager cancelRequest:self];
    
}


@end
