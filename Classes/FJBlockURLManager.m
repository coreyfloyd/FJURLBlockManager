#import "FJBlockURLManager.h"
#import "FJBlockURLRequest.h"

@interface FJBlockURLRequest (FJNetworkBlockManager)

@property (nonatomic, retain) NSThread *connectionThread;
@property (readwrite) FJBlockURLStatusType status; 
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

//config
@property (nonatomic, readwrite) FJNetworkBlockManagerType type;       
@property (nonatomic, readwrite) NSInteger maxConcurrentRequests;     
@property (nonatomic, readwrite) NSInteger maxScheduledRequests;       


- (void)scheduleRequest:(FJBlockURLRequest*)req;

- (void)_addRequest:(FJBlockURLRequest*)req;

- (FJBlockURLRequest*)_nextRequest;
- (void)_sendNextRequest;
- (void)_removeActiveRequest:(FJBlockURLRequest*)req;

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


+ (FJBlockURLManager*)defaultManager{
    
    if(_defaultManager == nil){
        _defaultManager = [[FJBlockURLManager alloc] initWithType:FJNetworkBlockManagerQueue concurrentRequests:4 scheduledRequests:NSIntegerMax];
    }
    
    return _defaultManager;
}

+ (void)setDefaultManager:(FJBlockURLManager*)aManager{
    
    if(_defaultManager != aManager){
        
        [aManager retain];
        [_defaultManager release];
        _defaultManager = aManager;
        
    }
}

- (id)initWithType:(FJNetworkBlockManagerType)aType concurrentRequests:(NSInteger)concurrent scheduledRequests:(NSInteger)scheduled{
    
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
        self.type = aType;
        self.maxScheduledRequests = scheduled;
        self.maxConcurrentRequests = concurrent;        
        self.idle = YES;
        
        
    }
    return self;
    
}


- (NSArray*)allRequests{
    
    __block NSMutableArray* a  = [NSMutableArray array];
    
    dispatch_sync(self.workQueue, ^{
        
        [a addObjectsFromArray:self.requests];
        [a addObjectsFromArray:self.activeRequests];
        
    });
    
  
    [a addObjectsFromArray:self.activeRequests];
    
    return a;
    
}
      
#pragma mark -
#pragma Suspend / Resume


- (void)suspend{
    
     extendedDebugLog(@"susupended");
    dispatch_suspend(self.workQueue);
    
}
- (void)resume{
    
    extendedDebugLog(@"resumed");
    dispatch_resume(self.workQueue);
    
}

#pragma mark -
#pragma mark Send Request

- (void)scheduleRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.workQueue, ^{
                
         extendedDebugLog(@"Manager scheduling url: %@", [[req URL] description]);
        
        req.connectionThread = [FJBlockURLManager sharedThread];
        
        [self _addRequest:req];
        
        [self _sendNextRequest];
        
    });
}

- (void)_addRequest:(FJBlockURLRequest*)req{
    
    if(([self.requests count] + [self.activeRequests count] + 1) > self.maxScheduledRequests){ //looks like we have some trimming to do
        
        if(self.type == FJNetworkBlockManagerQueue){
            //full, can't add anymore
            dispatch_async(req.workQueue, ^{
                
                [req cancel];
                
            });
            
            return; //nothing to add
            
        }else{
            
            FJBlockURLRequest* requestToKill = [self.requests objectAtIndex:0];
            
            dispatch_async(requestToKill.workQueue, ^{
                
                [requestToKill cancel];
                
            });
            
        }
        
    }
    
    [req addObserver:self forKeyPath:@"status" options:0 context:nil]; //TODO: possibly call on request queue
    
    [self.requests addObject:req];
    [self.requestMap setObject:req forKey:[NSString stringWithInt:[req hash]]];
    
}

- (void)_sendNextRequest{
    
    if([self.requests count] == 0){
        self.idle = YES;
        return;
    }
    
    
    extendedDebugLog(@"number of requests: %i", [self.requests count]);
    
    FJBlockURLRequest* nextRequest = [self _nextRequest];
    
    if(nextRequest == nil)
        return;
    
    self.idle = NO;
    
    extendedDebugLog(@"url to fetch: %@", [[nextRequest URL] description]);
    
    extendedDebugLog(@"concurrentReq: %i", [self.activeRequests count]);
    
    [nextRequest start];
    
}

- (FJBlockURLRequest*)_nextRequest{
    
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
    [self.activeRequests addObject:nextRequest];
    [self.requests removeObjectAtIndex:index];    
    
    return nextRequest;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if(keyPath == @"status"){
        
        FJBlockURLRequest* req = (FJBlockURLRequest*)object;

        if(req.status == FJBlockURLStatusFinished || 
           req.status == FJBlockURLStatusError || 
           req.status == FJBlockURLStatusCancelled){
            

            dispatch_async(self.workQueue, ^{
                
                [self _removeActiveRequest:req];

                [self _sendNextRequest];

            });
            
        }
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark -
#pragma mark Cancel Requests

//only call on an active (and therefore currently kvo'd) request
- (void)_removeActiveRequest:(FJBlockURLRequest*)req{
        
    dispatch_async(req.workQueue, ^{
        
        [req removeObserver:self forKeyPath:@"status"];
        
    });
    
    [self.requestMap removeObjectForKey:[NSString stringWithInt:[req hash]]];
    [self.requests removeObject:req];
    [self.activeRequests removeObject:req];
    
}


- (void)cancelAllRequests{
    
    dispatch_suspend(self.workQueue);
    
    dispatch_async(self.configurationQueue, ^{
        
        [self.requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            
            FJBlockURLRequest* req = (FJBlockURLRequest*)obj;
            
            [req cancel];

        }];
        
        
        dispatch_resume(self.workQueue); //TODO: move inside the async call to ensure we dont resume until after all requests have been cancelled.
        
    });
}

@end
