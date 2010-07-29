#import "FJBlockURLManager.h"
#import "FJBlockURLRequest.h"

@interface FJBlockURLRequest (FJNetworkBlockManager)

- (BOOL)start; 

@end


static FJBlockURLManager* _defaultmanager = nil;

@interface FJBlockURLManager()

@property (nonatomic, retain, readwrite) NSThread *requestThread;
@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSMutableDictionary *requestMap;

- (FJBlockURLRequest*)nextRequest;
- (void)sendNextRequest;

- (void)trimRequests;

- (void)removeRequest:(FJBlockURLRequest*)req;

@end


@implementation FJBlockURLManager

@synthesize requestThread;
@synthesize managerQueue;
@synthesize type;

@synthesize requests;
@synthesize requestMap;

@synthesize maxConcurrentRequests;
@synthesize maxScheduledRequests;

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



+(FJBlockURLManager*)defaultManager{
    
    if(_defaultmanager == nil){
        _defaultmanager = [[FJBlockURLManager alloc] init];
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
        self.maxScheduledRequests = 100;
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
    
    //NSLog(@"Tick");
    //nonop
}



- (void)scheduleRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.managerQueue, ^{
        
        NSLog(@"url to schedule: %@", [[req URL] description]);
        
        [self.requests addObject:req];
        
        [self trimRequests];
        
        [self sendNextRequest];
        
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
        
        NSLog(@"url to fetch: %@", [[nextRequest URL] description]);

        
        [nextRequest start];
        [nextRequest addObserver:self forKeyPath:@"isFinished" options:0 context:nil]; //TODO: possibly call on request queue
        
    });
}

- (FJBlockURLRequest*)nextRequest{
    
    NSIndexSet* currentRequestIndexes = [self.requests indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^(id obj, NSUInteger idx, BOOL *stop){
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
        
        __block BOOL answer = NO;
        
        dispatch_sync(req.workQueue, ^{
        
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

            dispatch_sync(req.workQueue, ^{
                
                answer = (!req.inProcess && !req.isFinished);
                
            });
            
            *stop = answer;
                          
            return answer;
        }];
        
    }else{
        
        index = [self.requests indexOfObjectWithOptions:NSEnumerationReverse passingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
            __block BOOL answer = NO;
            
            dispatch_sync(req.workQueue, ^{
                
                answer = (!req.inProcess && !req.isFinished);
                
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
    
    if(keyPath == @"isFinished"){
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)object;

        dispatch_async(req.workQueue, ^{

            if(req.inProcess == NO){
                
                [req removeObserver:self forKeyPath:@"isFinished"];

                dispatch_async(self.managerQueue, ^{
                    
                    [self.requests removeObject:req];
                    [self sendNextRequest];
                    
                });
            }
            
        });
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}



- (void)trimRequests{
    
    dispatch_async(self.managerQueue, ^{
        
        if([self.requests count] > self.maxScheduledRequests){
            
            FJBlockURLRequest* requestToKill = nil;
            
            if(self.type == FJNetworkBlockManagerQueue)
                requestToKill = [self.requests lastObject];
            else
                requestToKill = [self.requests objectAtIndex:0];
            
            dispatch_async(requestToKill.workQueue, ^{
                
                [requestToKill cancel];
            });
            
        }
    });
}

//always called by request
- (void)cancelRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.managerQueue, ^{
        
        int index = [self.requests indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* request = (FJBlockURLRequest*)obj;
            
            if([request isEqual:req]){
                *stop = YES;
                return YES;
            }
            
            return NO;
        }];
        
        
        if(index != NSNotFound){
            
            [self removeRequest:[self.requests objectAtIndex:index]];
            
        }
    });
}


- (void)cancelAllRequests{
    
    dispatch_async(self.managerQueue, ^{
        
        [self.requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
            dispatch_sync(req.workQueue, ^{
                
                if(req.inProcess)
                    [req removeObserver:self forKeyPath:@"isFinished"];
                
            });
            
            [req cancel];
            
        }];
        
        [self.requests removeAllObjects];
        
    });
}

//always called internally
- (void)removeRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.managerQueue, ^{
        
        dispatch_sync(req.workQueue, ^{
            
            if(req.inProcess)
                [req removeObserver:self forKeyPath:@"isFinished"];
            
        });
        
        [req cancel];
        
        [self.requests removeObject:req];
        
        
    });
    
}

@end
