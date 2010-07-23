#import "FJNetworkBlockManager.h"

int const maxAttempts = 3;

@interface FJNetworkBlockRequest : NSObject {

    NSURLRequest* request;

    NSThread* connectionThread;
    NSURLConnection* connection;

    dispatch_queue_t requestQueue;
    NSMutableData* responseData;
    BOOL inProcess;
    int attempt;

    dispatch_queue_t completionQueue;
    FJNetworkResponseHandler completionBlock;
    FJNetworkErrorHandler failureBlock;
    
}
@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic) dispatch_queue_t requestQueue;
@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic) dispatch_queue_t completionQueue;
@property (nonatomic, copy) FJNetworkResponseHandler completionBlock;
@property (nonatomic, copy) FJNetworkErrorHandler failureBlock;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic) BOOL inProcess;
@property (nonatomic) int attempt;


- (id)initWithRequest:(NSURLRequest*)req
     connectionThread:(NSThread*)thread
      completionQueue:(dispatch_queue_t)queue       //can be nil, defaults to main queue
      completionBlock:(FJNetworkResponseHandler)completion 
         failureBlock:(FJNetworkErrorHandler)failure;        

- (void)start;
- (void)cancel;


@end

@implementation FJNetworkBlockRequest

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
        
        self.completionBlock([[self.responseData copy] autorelease]);
        
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





static FJNetworkBlockManager* _defaultmanager = nil;

@interface FJNetworkBlockManager()

@property (nonatomic, retain) NSThread *requestThread;
@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSMutableDictionary *requestMap;

- (FJNetworkBlockRequest*)nextRequest;
- (void)sendNextRequest;

- (void)cleanupRequest:(FJNetworkBlockRequest*)req;
- (void)trimRequests;

@end


@implementation FJNetworkBlockManager

@synthesize requestThread;
@synthesize managerQueue;
@synthesize type;

@synthesize requests;
@synthesize requestMap;

@synthesize maxConcurrentRequests;
@synthesize maxRequestsInQueue;

@synthesize idle;



- (void) dealloc
{
    [requestMap release];
    requestMap = nil;
    [requests release];
    requests = nil;
    dispatch_release(managerQueue);
    [requestThread release];
    requestThread = nil;
    [super dealloc];
}



+(FJNetworkBlockManager*)defaultManager{
    
    if(_defaultmanager == nil){
        _defaultmanager = [[FJNetworkBlockManager alloc] init];
    }
    
    return _defaultmanager;
}


- (id) init
{
    self = [super init];
    if (self != nil) {
                
        self.requests = [NSMutableArray arrayWithCapacity:10];
        self.requestMap = [NSMutableDictionary dictionaryWithCapacity:10];
        self.type = FJNetworkBlockManagerQueue;
        self.maxRequestsInQueue = 100;
        self.maxConcurrentRequests = 2;
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManager.%i", [self hash]];
        self.managerQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(managerQueue);

        
        self.requestThread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
        [self.requestThread start];
                
    }
    return self;
}


- (void)run{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(keepAlive) userInfo:nil repeats:YES];
    
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
	
	[pool release];
}

- (void)keepAlive{
    
    NSLog(@"Tick");
    //nonop
}



- (void) sendRequest:(NSURLRequest*)req 
      respondOnQueue:(dispatch_queue_t)queue 
     completionBlock:(FJNetworkResponseHandler)completionBlock 
        failureBlock:(FJNetworkErrorHandler)errorBlock{
    
    dispatch_async(self.managerQueue, ^{
        
        NSLog(@"url to enque: %@", [[req URL] description]);

        
        FJNetworkBlockRequest* request = [[FJNetworkBlockRequest alloc] initWithRequest:req 
                                                                           connectionThread:self.requestThread 
                                                                            completionQueue:queue 
                                                                            completionBlock:completionBlock 
                                                                               failureBlock:errorBlock];
        
        [self.requests addObject:request];
        [self.requestMap setObject:request forKey:request.request];
        
        [self trimRequests];

        [self sendNextRequest];
        
    });
            
        
}


- (void)cancelRequest:(NSURLRequest*)req{
    
    dispatch_async(self.managerQueue, ^{

        int index = [self.requests indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJNetworkBlockRequest* request = (FJNetworkBlockRequest*)obj;
            
            if([request.request isEqual:req]){
                *stop = YES;
                return YES;
            }
            
            return NO;
        }];
        
        
        if(index != NSNotFound){
            
            FJNetworkBlockRequest* req = [self.requests objectAtIndex:index];
            [req cancel];
            [self cleanupRequest:req];
            
        }
        
    });
}


- (void)cancelAllRequests{
    
    dispatch_async(self.managerQueue, ^{
        
        [self.requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJNetworkBlockRequest* req = (FJNetworkBlockRequest*)obj;
                                    
            dispatch_sync(req.requestQueue, ^{
                
                if(req.inProcess)
                    [req removeObserver:self forKeyPath:@"inProcess"];
                
            });
                        
            [req cancel];
            
        }];
        
        [self.requests removeAllObjects];
        [self.requestMap removeAllObjects];
        
    });
}


- (void)sendNextRequest{
    
    dispatch_async(self.managerQueue, ^{
        
        if([self.requests count] == 0){
            self.idle = YES;
            return;
        }
        
        NSLog(@"number of requests: %i", [self.requests count]);

        FJNetworkBlockRequest* nextRequest = [self nextRequest];
        
        if(nextRequest == nil)
            return;
        
        NSLog(@"url to fetch: %@", [[[nextRequest request] URL] description]);

        
        [nextRequest start];
        [nextRequest addObserver:self forKeyPath:@"inProcess" options:0 context:nil]; //TODO: possibly call on request queue
        
    });
}

- (FJNetworkBlockRequest*)nextRequest{
    
    NSIndexSet* currentRequestIndexes = [self.requests indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^(id obj, NSUInteger idx, BOOL *stop){
        
        FJNetworkBlockRequest* req = (FJNetworkBlockRequest*)obj;
        
        __block BOOL answer = NO;
        
        dispatch_sync(req.requestQueue, ^{
        
            answer = req.inProcess;
            
        });
            
        return answer;
        
    }];
    
    
    if([currentRequestIndexes count] >= self.maxConcurrentRequests)
        return nil;
    
    FJNetworkBlockRequest* nextRequest = nil;
    
    int index = NSNotFound;
    
    if(self.type == FJNetworkBlockManagerQueue){
        
        index = [self.requests indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJNetworkBlockRequest* req = (FJNetworkBlockRequest*)obj;
            
            __block BOOL answer = NO;

            dispatch_sync(req.requestQueue, ^{
                
                answer = !req.inProcess;
                
            });
            
            *stop = answer;
                          
            return answer;
        }];
        
    }else{
        
        index = [self.requests indexOfObjectWithOptions:NSEnumerationReverse passingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJNetworkBlockRequest* req = (FJNetworkBlockRequest*)obj;
            
            __block BOOL answer = NO;
            
            dispatch_sync(req.requestQueue, ^{
                
                answer = !req.inProcess;
                
            });
            
            *stop = answer;
            
            return answer;
        }];
    }
    
    if(index == NSNotFound){
        
        NSLog(@"all requests in motion");
            
        return nil;
    }
    
    nextRequest = [self.requests objectAtIndex:index];
    
    return nextRequest;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if(keyPath == @"inProcess"){
        
        FJNetworkBlockRequest* req = (FJNetworkBlockRequest*)object;

        dispatch_async(req.requestQueue, ^{

            if(req.inProcess == NO){
                
                dispatch_async(self.managerQueue, ^{
                    
                    [self cleanupRequest:req];
                    [self sendNextRequest];
                    
                });
            }
            
        });
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


- (void)cleanupRequest:(FJNetworkBlockRequest*)req{
    
    dispatch_async(self.managerQueue, ^{

        dispatch_sync(req.requestQueue, ^{

        if(req.inProcess)
            [req removeObserver:self forKeyPath:@"inProcess"];
            
        });
         
        [self.requests removeObject:req];
        [self.requestMap removeObjectForKey:req.request];
        
    });
}


- (void)trimRequests{
    
    dispatch_async(self.managerQueue, ^{
        
        if([self.requests count] > self.maxRequestsInQueue){
            
            FJNetworkBlockRequest* requestToKill = nil;
            
            if(self.type == FJNetworkBlockManagerQueue)
                requestToKill = [self.requests lastObject];
            else
                requestToKill = [self.requests objectAtIndex:0];
            
            [requestToKill performSelector:@selector(cancel) onThread:self.requestThread withObject:nil waitUntilDone:YES];
            [self cleanupRequest:requestToKill];
        }
        
    });
}

@end
