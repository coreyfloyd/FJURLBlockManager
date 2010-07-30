#import "FJBlockURLManager.h"
#import "FJBlockURLRequest.h"

@interface FJBlockURLRequest (FJNetworkBlockManager)

@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic) dispatch_queue_t workQueue; //need to make some changes, use this queue
- (BOOL)start; 

@end


static FJBlockURLManager* _defaultManager = nil;
static NSThread* _sharedThread = nil;

@interface FJBlockURLManager()

@property (nonatomic) dispatch_queue_t managerQueue; 
@property (nonatomic) dispatch_queue_t configurationQueue; 
@property (nonatomic) dispatch_queue_t workQueue;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSMutableArray *activeRequests;
@property (nonatomic, retain) NSMutableDictionary *requestMap;
@property (nonatomic, readwrite) BOOL idle;                            

- (void)addRequest:(FJBlockURLRequest*)req;

- (FJBlockURLRequest*)nextRequest;
- (void)sendNextRequest;

- (void)removeRequest:(FJBlockURLRequest*)req;

@end


@implementation FJBlockURLManager

@synthesize workQueue;
@synthesize configurationQueue;
@synthesize managerQueue;

@synthesize type;

@synthesize requests;
@synthesize activeRequests;
@synthesize requestMap;

@synthesize maxConcurrentRequests;
@synthesize maxScheduledRequests;

@synthesize idle;

#pragma mark -
#pragma mark Initialization / Deallocation

- (void) dealloc
{
    [requestMap release];
    requestMap = nil;
    [activeRequests release];
    activeRequests = nil;
    [requests release];
    requests = nil;
    dispatch_release(workQueue);
    dispatch_release(configurationQueue);
    dispatch_release(managerQueue);
    [super dealloc];
}

+ (NSThread*)sharedThread{
    
    if(_sharedThread == nil){
        
        _sharedThread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
        [_sharedThread setThreadPriority:0.0];
        [_sharedThread start];        
    }
    
    return _sharedThread;
}


+ (void)run{
    
    while (![_sharedThread isCancelled]) {
        
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
        
        [pool release];
        
    }
}


+(FJBlockURLManager*)defaultManager{
    
    if(_defaultManager == nil){
        _defaultManager = [[FJBlockURLManager alloc] init];
    }
    
    return _defaultManager;
}


- (id) init
{
    self = [super init];
    if (self != nil) {
                
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManager.%i", [self hash]];
        self.managerQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(managerQueue);
        
        queueName = [NSString stringWithFormat:@"com.FJNetworkManager.%i.workQueue", [self hash]];
        self.workQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(workQueue);
        dispatch_set_target_queue(self.workQueue, self.managerQueue);  
        
        queueName = [NSString stringWithFormat:@"com.FJNetworkManager.%i.configurationQueue", [self hash]];
        self.configurationQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(configurationQueue);
        dispatch_set_target_queue(self.configurationQueue, self.managerQueue);  
        
        self.requests = [NSMutableArray arrayWithCapacity:10];
        self.activeRequests = [NSMutableArray arrayWithCapacity:10];
        self.requestMap = [NSMutableDictionary dictionaryWithCapacity:10];
        self.type = FJNetworkBlockManagerQueue;
        self.maxScheduledRequests = 100;
        self.maxConcurrentRequests = 2;
        
               
    }
    return self;
}

#pragma mark -
#pragma mark Accssors

- (void)setType:(FJNetworkBlockManagerType)aType{
    
    dispatch_suspend(self.workQueue);
    
    dispatch_async(self.configurationQueue, ^{
        
        type = aType;
        
        dispatch_resume(self.workQueue);
    });
}

- (void)setMaxConcurrentRequests:(NSInteger)value{
    
    dispatch_suspend(self.workQueue);
    
    dispatch_async(self.configurationQueue, ^{
        
        maxConcurrentRequests = value;
        
        dispatch_resume(self.workQueue);
    });
    
}
                   
- (void)setMaxScheduledRequests:(NSInteger)value{
    
    dispatch_suspend(self.workQueue);
    
    dispatch_async(self.configurationQueue, ^{
        
        maxScheduledRequests = value;
        
        dispatch_resume(self.workQueue);
    });
}
      
#pragma mark -
#pragma Suspend / Resume


- (void)suspend{
    
    NSLog(@"susupended");
    dispatch_suspend(self.workQueue);
    
}
- (void)resume{
    
    NSLog(@"resumed");
    dispatch_resume(self.workQueue);
    
}

#pragma mark -
#pragma mark Send Request



- (void)scheduleRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.workQueue, ^{
        
        NSLog(@"url to schedule: %@", [[req URL] description]);
        
        req.connectionThread = [FJBlockURLManager sharedThread];
        
        [self addRequest:req];
        
        [self sendNextRequest];
        
    });
}

- (void)addRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.workQueue, ^{
        
        if(([self.requests count] + [self.activeRequests count] + 1) > self.maxScheduledRequests){ //looks like we have some trimming to do
            
            if(self.type == FJNetworkBlockManagerQueue)
                return; //full, can't add anymore
            
            [self.requests addObject:req];
            
            FJBlockURLRequest* requestToKill = [self.requests objectAtIndex:0];
            
            dispatch_async(requestToKill.workQueue, ^{
                
                [requestToKill cancel];
                
            });
            
        }else{
            
            [self.requests addObject:req];

        }
        
    });
    
}

- (void)sendNextRequest{
    
    dispatch_async(self.workQueue, ^{
        
        if([self.requests count] == 0){
            self.idle = YES;
            return;
        }
        
        NSLog(@"number of requests: %i", [self.requests count]);

        FJBlockURLRequest* nextRequest = [self nextRequest];
        
        if(nextRequest == nil)
            return;
        
        NSLog(@"url to fetch: %@", [[nextRequest URL] description]);

        [self.activeRequests addObject:nextRequest];
        [self.requests removeObject:nextRequest];
        
        [nextRequest start];
        [nextRequest addObserver:self forKeyPath:@"isFinished" options:0 context:nil]; //TODO: possibly call on request queue
        
    });
}

- (FJBlockURLRequest*)nextRequest{
    
    if([self.activeRequests count] >= self.maxConcurrentRequests)
        return nil;
    if([self.requests count] == 0)
        return nil;
        
    int index = NSNotFound;
    
    if(self.type == FJNetworkBlockManagerQueue){
        
        index = 0;
        
    }else{
        
        index = [self.requests count]-1;
    }
        
    FJBlockURLRequest* nextRequest = [self.requests objectAtIndex:index];
    
    return nextRequest;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if(keyPath == @"isFinished"){
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)object;

        if(req.isFinished == YES){
            
            dispatch_async(req.workQueue, ^{
                
                [req removeObserver:self forKeyPath:@"isFinished"];
                
            });
            
            dispatch_async(self.workQueue, ^{
                
                [self.requests removeObject:req];
                [self.activeRequests removeObject:req];
                [self sendNextRequest];
                
            });
        }
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark -
#pragma mark Cancel Requests

//always called by request
- (void)cancelRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.workQueue, ^{
        
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
    
    dispatch_suspend(self.workQueue);
    
    dispatch_async(self.configurationQueue, ^{
        
        [self.requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
            dispatch_async(req.workQueue, ^{
                
                if(req.inProcess)
                    [req removeObserver:self forKeyPath:@"isFinished"];
                
            });
            
            [req cancel];
            
        }];
        
        [self.requests removeAllObjects];
        [self.activeRequests removeAllObjects];
        
        dispatch_resume(self.workQueue);
        
    });
}

//always called internally
- (void)removeRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(req.workQueue, ^{
        
        if(req.inProcess)
            [req removeObserver:self forKeyPath:@"isFinished"];
        
    });
    
    dispatch_async(self.workQueue, ^{
        
        [req cancel];
        
        [self.requests removeObject:req];
        [self.activeRequests removeObject:req];
        
    });
    
}

@end
