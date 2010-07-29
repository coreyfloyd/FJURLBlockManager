#import "FJBlockURLRequest.h"
#import "FJBlockURLManager.h"

//#define USE_CHARLES_PROXY

@interface FJBlockURLManager (FJBlockURLRequest)

- (void)scheduleRequest:(FJBlockURLRequest*)req;
- (void)cancelRequest:(FJBlockURLRequest*)req;


@end

int const kMaxAttempts = 3;

@interface FJBlockURLRequest()

@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic, retain) NSURLConnection *connection;

@property (nonatomic, readwrite) BOOL inProcess; 
@property (nonatomic, readwrite) BOOL isFinished; 
@property (nonatomic, readwrite) int attempt; 

@property (nonatomic, readwrite) dispatch_queue_t workQueue;

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
@synthesize inProcess;
@synthesize isFinished;
@synthesize attempt;
@synthesize responseData;
@synthesize maxAttempts;


- (void) dealloc
{
    
    [responseData release];
    responseData = nil;    
   
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
        
        NSLog(@"starting request: %@", [self description]);

        
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
    
    NSLog(@"opening connection for request: %@", [self description]);
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self delegate:self];
    
    if(connection){
        
        dispatch_async(self.workQueue, ^{
            
            self.isFinished = NO;
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
    
    dispatch_async(self.workQueue, ^{
        
        [responseData setLength:0];
        
    });
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    dispatch_async(self.workQueue, ^{
        
        [responseData appendData:data];
        
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    dispatch_async(self.workQueue, ^{
        
        NSString *failureMessage = [NSString stringWithFormat:@"Connection failed: %@", [error description]];
        NSLog(@"%@", failureMessage);
        
        self.attempt++;
        
        if(self.attempt > self.maxAttempts){
            
            self.responseData = nil;
            
            if(responseQueue && failureBlock){
                
                dispatch_async(self.responseQueue, ^{
                    
                    self.failureBlock(error);
                    
                    dispatch_async(self.workQueue, ^{
                        
                        self.isFinished = YES;
                        self.inProcess = NO;
                        
                    });
                    
                });
                
            }else{
                
                self.isFinished = YES;
                self.inProcess = NO;
            }
            
        }else{
            
            [self openConnection];
            
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if(completionBlock){
        
        dispatch_async(self.responseQueue, ^{
            
            //NSLog(@"Queue check: %@", [self.responseData description]);

            self.completionBlock(self.responseData);
            
            dispatch_async(self.workQueue, ^{
                
                //NSLog(@"Doublecheck: %@", [self.responseData description]);
                
                self.isFinished = YES;
                self.inProcess = NO;
            });
            
        });
        
    }else{
        
        self.isFinished = YES;
        self.inProcess = NO;

    }
    
    
}


- (void)cancel{
    
    dispatch_async(self.workQueue, ^{
        
        [self.connection performSelector:@selector(cancel) 
                                onThread:self.connectionThread 
                              withObject:nil 
                           waitUntilDone:NO];
        
        self.responseData = nil;
        
        self.isFinished = NO;
        self.inProcess = NO;
        
    });
    
    [self.manager cancelRequest:self];
    
}


@end
