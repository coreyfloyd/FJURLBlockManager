#import "FJBlockURLManager.h"
#import "FJBlockURLRequest.h"

@interface FJBlockURLRequest (FJNetworkBlockManager)

@property (nonatomic, retain) NSThread *connectionThread;
- (BOOL)start; 

@end


static FJBlockURLManager* _defaultManager = nil;
static NSThread* _sharedThread = nil;

@interface FJBlockURLManager()

@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSMutableArray *activeRequests;
@property (nonatomic, retain) NSMutableDictionary *requestMap;

- (FJBlockURLRequest*)nextRequest;
- (void)sendNextRequest;

- (void)trimRequests;

- (void)removeRequest:(FJBlockURLRequest*)req;

@end


@implementation FJBlockURLManager

@synthesize managerQueue;
@synthesize type;

@synthesize requests;
@synthesize activeRequests;
@synthesize requestMap;

@synthesize maxConcurrentRequests;
@synthesize maxScheduledRequests;

@synthesize idle;



- (void) dealloc
{
    [requestMap release];
    requestMap = nil;
    [activeRequests release];
    activeRequests = nil;
    [requests release];
    requests = nil;
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
                
        self.requests = [NSMutableArray arrayWithCapacity:10];
        self.requestMap = [NSMutableDictionary dictionaryWithCapacity:10];
        self.type = FJNetworkBlockManagerQueue;
        self.maxScheduledRequests = 100;
        self.maxConcurrentRequests = 2;
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJNetworkManager.%i", [self hash]];
        self.managerQueue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_retain(managerQueue);

    }
    return self;
}




- (void)scheduleRequest:(FJBlockURLRequest*)req{
    
    dispatch_async(self.managerQueue, ^{
        
        NSLog(@"url to schedule: %@", [[req URL] description]);
        
        req.connectionThread = [FJBlockURLManager sharedThread];
        
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
