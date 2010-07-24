#import "FJNetworkBlockManager.h"

#import "FJBlockURLRequest.h"

static FJNetworkBlockManager* _defaultmanager = nil;

@interface FJNetworkBlockManager()

@property (nonatomic, retain) NSThread *requestThread;
@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSMutableDictionary *requestMap;

- (FJBlockURLRequest*)nextRequest;
- (void)sendNextRequest;

- (void)cleanupRequest:(FJBlockURLRequest*)req;
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

        
        FJBlockURLRequest* request = [[FJBlockURLRequest alloc] initWithRequest:req 
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
            
            FJBlockURLRequest* request = (FJBlockURLRequest*)obj;
            
            if([request.request isEqual:req]){
                *stop = YES;
                return YES;
            }
            
            return NO;
        }];
        
        
        if(index != NSNotFound){
            
            FJBlockURLRequest* req = [self.requests objectAtIndex:index];
            [req cancel];
            [self cleanupRequest:req];
            
        }
        
    });
}


- (void)cancelAllRequests{
    
    dispatch_async(self.managerQueue, ^{
        
        [self.requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
                                    
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

        FJBlockURLRequest* nextRequest = [self nextRequest];
        
        if(nextRequest == nil)
            return;
        
        NSLog(@"url to fetch: %@", [[[nextRequest request] URL] description]);

        
        [nextRequest start];
        [nextRequest addObserver:self forKeyPath:@"inProcess" options:0 context:nil]; //TODO: possibly call on request queue
        
    });
}

- (FJBlockURLRequest*)nextRequest{
    
    NSIndexSet* currentRequestIndexes = [self.requests indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^(id obj, NSUInteger idx, BOOL *stop){
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
        
        __block BOOL answer = NO;
        
        dispatch_sync(req.requestQueue, ^{
        
            answer = req.inProcess;
            
        });
            
        return answer;
        
    }];
    
    
    if([currentRequestIndexes count] >= self.maxConcurrentRequests)
        return nil;
    
    FJBlockURLRequest* nextRequest = nil;
    
    int index = NSNotFound;
    
    if(self.type == FJNetworkBlockManagerQueue){
        
        index = [self.requests indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
            __block BOOL answer = NO;

            dispatch_sync(req.requestQueue, ^{
                
                answer = !req.inProcess;
                
            });
            
            *stop = answer;
                          
            return answer;
        }];
        
    }else{
        
        index = [self.requests indexOfObjectWithOptions:NSEnumerationReverse passingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
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
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)object;

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


- (void)cleanupRequest:(FJBlockURLRequest*)req{
    
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
            
            FJBlockURLRequest* requestToKill = nil;
            
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
