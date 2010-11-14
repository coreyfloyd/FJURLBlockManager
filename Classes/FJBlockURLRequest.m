#import "FJBlockURLRequest.h"
#import "FJBlockURLManager.h"

//#define USE_CHARLES_PROXY



NSString* const FJBlockURLErrorDomain = @"FJBlockURLErrorDomain";




@interface FJBlockURLManager (FJBlockURLRequest)

- (void)scheduleRequest:(FJBlockURLRequest*)req;

@end

int const kMaxAttempts = 3;

@interface FJBlockURLRequest()

@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic, retain) NSURLConnection *connection;

@property (readwrite) FJBlockURLStatusType status; 
@property (readwrite) int attempt; 

@property (readwrite) NSUInteger responseCode; 
@property (nonatomic, retain, readwrite) NSMutableData *responseData; 
@property (nonatomic, retain, readwrite) id formattedResponse; 
@property (nonatomic, retain, readwrite) NSHTTPURLResponse* HTTPResponse; 
@property (nonatomic, readwrite) long long expectedResponseDataLength; 
@property (nonatomic, readwrite) long long responseDataLength;

@property (nonatomic, retain, readwrite) NSMutableIndexSet* acceptedResponseCodes; 

@property (nonatomic, readwrite) dispatch_queue_t workQueue;
@property (nonatomic, assign, readwrite) FJBlockURLManager *manager; 

- (void)_openConnection;

- (void)_handleResponseError:(NSError*)error;
- (void)_dipatchSuccessfulResponse;
- (void)_dispatchUnsuccessfulResponseWithError:(NSError*)error;


@end

@implementation FJBlockURLRequest

@synthesize manager;
@synthesize connectionThread;
@synthesize workQueue;
@synthesize connection;
@synthesize responseQueue;
@synthesize completionBlock;
@synthesize uploadProgressBlock;
@synthesize failureBlock;
@synthesize attempt;
@synthesize responseData;
@synthesize maxAttempts;
@synthesize headerProvider;
@synthesize cacheResponse;
@synthesize responseFormatter;
@synthesize formattedResponse;
@synthesize acceptedResponseCodes;
@synthesize responseCode;
@synthesize HTTPResponse;
@synthesize status;
@synthesize requestStartedBlock;
@synthesize incrementalResponseBlock;
@synthesize retainAndAppendResponseData;
@synthesize expectedResponseDataLength;
@synthesize responseDataLength;
@synthesize uploadFileURL;



- (void) dealloc
{
    
    responseFormatter = nil;
    headerProvider = nil;
    
    [uploadFileURL release];
    uploadFileURL = nil;
    
    [responseData release];
    responseData = nil;    
    
    [formattedResponse release];
    formattedResponse  = nil;
    
    [connection release];
    connection = nil;
    
    Block_release(incrementalResponseBlock);
    Block_release(requestStartedBlock);
    Block_release(uploadProgressBlock);
    Block_release(completionBlock);
    Block_release(failureBlock);
    
    dispatch_release(responseQueue);  
    dispatch_release(workQueue);
    
    [connectionThread release];
    connectionThread = nil; 
    [super dealloc];
}

- (id)initWithURL:(NSURL *)url cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval{
    
    if ((self = [super initWithURL:url cachePolicy:cachePolicy timeoutInterval:timeoutInterval])) {
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManagerRequest.%i", [self hash]];
        self.workQueue = dispatch_queue_create([queueName UTF8String], NULL);
        self.maxAttempts = kMaxAttempts;
        self.responseQueue = dispatch_get_main_queue();
        self.cacheResponse = YES;
        self.acceptedResponseCodes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
        self.retainAndAppendResponseData = YES;
        
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
    
    [headerProvider setHeaderFieldsForRequest:self];
        
    if(self.manager != nil && self.manager != networkManager){
        
        ALWAYS_ASSERT;
    }    
    
    self.status = FJBlockURLStatusScheduled;
    
    self.manager = networkManager;

    [networkManager scheduleRequest:self];
    
}

- (BOOL)start{
    
    __block BOOL didStart = YES;
    
    dispatch_sync(self.workQueue, ^{
        
        if(self.status == FJBlockURLStatusRunning){
            didStart = NO;
            return;
        }
        
        extendedDebugLog(@"manager: %@ starting request: %@", [self.manager description], [self description]);

        self.status = FJBlockURLStatusRunning;
        self.attempt = 0;
                
        if(!self.responseQueue){
            
            self.responseQueue = dispatch_get_main_queue();
            
        }
        
        if(self.requestStartedBlock)
            dispatch_sync(self.responseQueue, self.requestStartedBlock);
        
        [self performSelector:@selector(_openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        
    });
    
    return didStart;
}

- (void)_openConnection{
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        [self performSelector:@selector(_openConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
        return;
    }
    
    extendedDebugLog(@"opening connection for request: %@", [self description]);
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self delegate:self];
   
    if(retainAndAppendResponseData)
        self.responseData = [NSMutableData data];
    
    if(connection){
        
        dispatch_async(self.workQueue, ^{
            
            self.status = FJBlockURLStatusRunning;
            self.attempt++;
            self.responseCode = 0;
            self.expectedResponseDataLength = 0;
            self.responseDataLength = 0;
            
            if(self.uploadFileURL == nil){
                [self setHTTPBodyStream:nil];   
            }else{
                [self setHTTPBodyStream:[NSInputStream inputStreamWithURL:self.uploadFileURL]];
            }
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


- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
    
    //NSLog(@"uploaded bytes: %i total bytes uploaded: %i total to write: %i", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    
    if(self.uploadProgressBlock){
        
        dispatch_async(self.responseQueue, ^{
           
            self.uploadProgressBlock(totalBytesWritten, totalBytesExpectedToWrite);
            
        });

    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    if([response isKindOfClass:[NSHTTPURLResponse class]]){
        
        self.HTTPResponse = (NSHTTPURLResponse*)response;
        int code = [self.HTTPResponse statusCode];
        self.responseCode = code;
        self.expectedResponseDataLength = [self.HTTPResponse expectedContentLength];
    }
    
    [responseData setLength:0];

    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
    if(self.retainAndAppendResponseData)
        [responseData appendData:data];
    
    self.responseDataLength += [data length];
    
    if(self.incrementalResponseBlock){
        
        dispatch_async(self.responseQueue, ^{
           
            self.incrementalResponseBlock(data, self.responseDataLength, self.expectedResponseDataLength);
            
        });
    }
        
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
    
     if([self.acceptedResponseCodes containsIndex:self.responseCode]){
         
         [self _dipatchSuccessfulResponse];
     }
    
    dispatch_async(self.workQueue, ^{
        
        NSString *failureMessage = [NSString stringWithFormat:@"Connection failed for request: %@ error: %@", [self description], [error description]];
        NSLog(@"%@", failureMessage);
        
        [self _handleResponseError:error];
        
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if(![[NSThread currentThread] isEqual:self.connectionThread]){
        ALWAYS_ASSERT;
    }
    
	//NSString * str = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
	//NSLog(@"error response: %@ " , str);
	
    extendedDebugLog(@"connection completed for request: %@", [self description]);
    
    //catch unaccepted response codes
    if(![self.acceptedResponseCodes containsIndex:self.responseCode]){
        
        [self _handleResponseError:[NSError invalidNetworkResponseErrorWithStatusCode:self.responseCode URL:[self URL]]];
        
    }else{
        
        [self _dipatchSuccessfulResponse];
                
    }
    
      
    
}

- (void)_dipatchSuccessfulResponse{
    
    __block id response = self.responseData;

    self.manager = nil;
    
    dispatch_async(self.workQueue, ^{
        //NSLog(@"Doublecheck: %@", [data description]);
        self.status = FJBlockURLStatusFinished;
    });

    
    if(self.responseFormatter == nil){
        
        if(self.completionBlock){
            
            dispatch_async(self.responseQueue, ^{
                
                self.completionBlock(response);
                
            });
        }
        
    }else if(self.responseFormatter != nil){
        
        id val = nil;
        
        if(response != nil && [response length] > 0)
            val = [self.responseFormatter formatResponse:response];
        
        if([val isKindOfClass:[NSError class]]){
            
            if(self.failureBlock){
                
                dispatch_async(self.responseQueue, ^{
                    
                    //self.failureBlock([NSError nilNetworkRespnseErrorWithURL:[self URL]]); //dont know why this was here???
					self.failureBlock(val);
                    
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

- (void)_handleResponseError:(NSError*)error{
    
    
    if(self.attempt >= self.maxAttempts){
                
        self.attempt = 0;

        self.responseData = nil;
        
        [self _dispatchUnsuccessfulResponseWithError:error];
        
        self.status = FJBlockURLStatusError;
        
        
    }else{
        
        [self _openConnection];
        
    }
}

- (void)_dispatchUnsuccessfulResponseWithError:(NSError*)error{
    
    if(!self.responseQueue || !self.failureBlock)
        return;
      
    self.manager = nil;

    dispatch_async(self.responseQueue, ^{
        
        self.failureBlock(error);
        
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
        
        self.responseCode = NSURLErrorCancelled;
        [self _dispatchUnsuccessfulResponseWithError:[NSError cancelledNetworkRequestWithURL:[self URL]]];

        self.status = FJBlockURLStatusCancelled;
                
    });
    
}



@end
