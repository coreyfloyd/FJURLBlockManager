
#import "FJImageCacheManager.h"
#import "NSString+extensions.h"


static NSString* folderName = @"Images";

NSString* imageDirectoryPath();
BOOL createImagesDirectory();
NSString* filePathWithName(NSString* name);
NSString* imageNameForURL(NSURL* url);
NSString* imagePathForURL(NSURL* url);


NSString* imageDirectoryPath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *filePath = [paths objectAtIndex:0]; 
	filePath = [filePath stringByAppendingPathComponent:folderName]; 
    
    return filePath;
}

BOOL createImagesDirectory()
{
	BOOL isDirectory;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:imageDirectoryPath() isDirectory:&isDirectory]) {
        
        if(!isDirectory){
            [[NSFileManager defaultManager] removeItemAtPath:imageDirectoryPath() error:nil];
        }
    }
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:imageDirectoryPath()]){
        [[NSFileManager defaultManager] createDirectoryAtPath:imageDirectoryPath() withIntermediateDirectories:YES attributes:nil error:nil];
        
    } 
    
	return [[NSFileManager defaultManager] fileExistsAtPath:imageDirectoryPath()];
}

NSString* filePathWithName(NSString* name)
{
	return [imageDirectoryPath() stringByAppendingPathComponent:name];	
}


NSString* imageNameForURL(NSURL* url)
{
	return [[url absoluteString] md5];
}

NSString* imagePathForURL(NSURL* url)
{
	return filePathWithName(imageNameForURL(url));
}



@interface FJImageCacheResponse : NSObject {
    
    NSURL* imageURL;
    id requester;
    dispatch_queue_t completionQueue;
    FJImageResponseHandler completionBlock;
    FJImageErrorHandler failureBlock;
    
}
@property (nonatomic, copy) NSURL *imageURL;
@property (nonatomic, retain) id requester;
@property (nonatomic) dispatch_queue_t completionQueue;
@property (nonatomic) FJImageResponseHandler completionBlock;
@property (nonatomic) FJImageErrorHandler failureBlock;

- (id)initWithRequest:(NSURL*)url
      completionQueue:(dispatch_queue_t)queue               //can be nil, defaults to main queue
      completionBlock:(FJImageResponseHandler)completion 
         failureBlock:(FJImageErrorHandler)failure
               object:(id)object;        


@end


@implementation FJImageCacheResponse

@synthesize imageURL;
@synthesize requester;
@synthesize completionQueue;
@synthesize completionBlock;
@synthesize failureBlock;

- (void) dealloc
{
    
    [requester release];
    requester = nil;
    [imageURL release];
    imageURL = nil;
    [super dealloc];
}

- (id)initWithRequest:(NSURL*)url
      completionQueue:(dispatch_queue_t)queue               
      completionBlock:(FJImageResponseHandler)completion 
         failureBlock:(FJImageErrorHandler)failure
               object:(id)object{
    
    
    self = [super init];
    if (self != nil) {
        self.imageURL = url;
        self.requester = object;
        self.completionQueue = queue;
        self.completionBlock = completion;
        self.failureBlock = failure;
    }
    return self;
    
}        


@end



static FJImageCacheManager* _defaultManager = nil;


@interface FJImageCacheManager()

@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) FJBlockURLManager *networkManager;
@property (nonatomic, retain) NSMutableDictionary *responses;
@property (nonatomic, retain) NSMutableDictionary *requests;


- (void)scheduleCompletionBlock:(FJImageResponseHandler)complete 
                  failutreBlock:(FJImageErrorHandler)fail
                        onQueue:(dispatch_queue_t)queue
                     withObject:(id)object
                         ForURL:(NSURL*)url;

- (NSMutableArray*)responsesForURL:(NSURL*)url;
- (FJImageCacheResponse*)responseForURL:(NSURL*)url object:(id)object;



@end

@implementation FJImageCacheManager


@synthesize managerQueue;
@synthesize networkManager;
@synthesize responses;
@synthesize requests;


- (void) dealloc
{
    dispatch_release(managerQueue);
    [networkManager release];
    networkManager = nil;
    [requests release];
    requests = nil;
    [responses release];
    responses = nil;
    [super dealloc];
}


+(FJImageCacheManager*)defaultManager{
    
    if(_defaultManager == nil){
        _defaultManager = [[FJImageCacheManager alloc] initWithNetworkManager:[FJBlockURLManager defaultManager]];
    }
    
    return _defaultManager;
}

- (id)initWithNetworkManager:(FJBlockURLManager*)manager{
    
    self = [super init];
    if (self != nil) {
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJImageCacheManager.%i", [self hash]];
        self.managerQueue = dispatch_queue_create([queueName UTF8String], NULL);\
        dispatch_retain(managerQueue);
        self.networkManager = [[[FJBlockURLManager alloc] init] autorelease]; 
        self.responses = [NSMutableDictionary dictionaryWithCapacity:10];
        self.requests = [NSMutableDictionary dictionaryWithCapacity:10];
        
        createImagesDirectory();
    }
    return self;
    
}

- (id) init
{
    return [self initWithNetworkManager:[FJBlockURLManager defaultManager]];
}

- (void)fetchImageAtURL:(NSURL*)imageURL                            
        completionBlock:(FJImageResponseHandler)completionBlock     
           failureBlock:(FJImageErrorHandler)errorBlock{
    
    [self fetchImageAtURL:imageURL 
           respondOnQueue:dispatch_get_main_queue() 
          completionBlock:completionBlock 
             failureBlock:errorBlock 
        requestedByobject:completionBlock];
    
}

- (void)fetchImageAtURL:(NSURL*)imageURL                            
         respondOnQueue:(dispatch_queue_t)queue                     
        completionBlock:(FJImageResponseHandler)completionBlock    
           failureBlock:(FJImageErrorHandler)errorBlock
      requestedByobject:(id)object{
    
    UIImage* i = [UIImage imageWithContentsOfFile:imagePathForURL(imageURL)];
    
    if(i != nil){
        
        dispatch_async(queue,  ^{
            
            completionBlock(i);
            
        });     
        
        return;
    }
    
    NSInteger urlIndex = [[self.requests allKeys] indexOfObjectPassingTest:^(id obj, NSUInteger indexOfObj, BOOL *stop) {
    
        if([obj isEqualToString:[imageURL absoluteString]]){
            
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    
    //new url
    if(urlIndex == NSNotFound){
        
        //add the request
        NSURLRequest* request = [NSURLRequest requestWithURL:imageURL];
        [self.requests setObject:request forKey:[imageURL absoluteString]];
        
        [self.networkManager sendRequest:request 
                          respondOnQueue:self.managerQueue 
                         completionBlock:^(NSData* result){
                             
                             UIImage* i = [UIImage imageWithData:result];
                            
                             
                             for(FJImageCacheResponse* each in [self responsesForURL:imageURL]){
                                FJImageResponseHandler comp = [each completionBlock];
                                 
                                 dispatch_queue_t q = [each completionQueue];
                                 
                                 dispatch_async(q,  ^{
                                     
                                     comp(i);
                                     
                                 });
                                 
                             }
                             
                             
                             NSString* path = imagePathForURL(imageURL);
                             
                             NSError* error = nil;
                             if(![[NSFileManager defaultManager] removeItemAtPath:path error:&error]){
                                 
                                 if(error!=nil){
                                     
                                     //handle error
                                 }
                             }
                             
                             if(![result writeToFile:path atomically:YES]){
                                 
                                 //handle write error
                                 
                             }    
                             
                             
                             
                         } failureBlock:^(NSError *error) {
                             
                             
                             for(FJImageCacheResponse* each in [self responsesForURL:imageURL]){
                                 
                                 FJImageErrorHandler fail = [each failureBlock];
                                 
                                 dispatch_queue_t q = [each completionQueue];
                                 
                                 dispatch_async(q,  ^{
                                     
                                     fail(error);
                                     
                                 });
                                 
                             }
                             
                             
                             //TODO: cleanup
                             
                             
                         }];

    }
    
   
    
    [self scheduleCompletionBlock:completionBlock 
                    failutreBlock:errorBlock 
                          onQueue:queue 
                       withObject:object 
                           ForURL:imageURL];
    

}       


- (void)cancelRequestForURL:(NSURL*)imageURL object:(id)object{
    
    FJImageCacheResponse* resp = [self responseForURL:imageURL object:object];
    
    NSMutableArray* r = [self responsesForURL:imageURL];
    
    [r removeObject:resp];
    
    if([r count] == 0){
        
        NSURLRequest* req = [self.requests objectForKey:imageURL];
        
        [self.networkManager cancelRequest:req];
        
        [self.requests removeObjectForKey:imageURL];
        
    }
}


- (void)cancelAllRequests{
    
    [self.networkManager cancelAllRequests];
    self.responses = [NSMutableDictionary dictionaryWithCapacity:10];
    
}


- (void)scheduleCompletionBlock:(FJImageResponseHandler)complete 
                  failutreBlock:(FJImageErrorHandler)fail
                        onQueue:(dispatch_queue_t)queue
                     withObject:(id)object
                         ForURL:(NSURL*)url{
    
    FJImageCacheResponse* newResp = [self responseForURL:url object:object];
    
    if(newResp == nil){
        
        newResp = [[FJImageCacheResponse alloc] initWithRequest:url 
                                                completionQueue:queue 
                                                completionBlock:complete 
                                                   failureBlock:fail 
                                                         object:object];
        
        [[self responsesForURL:url] addObject:newResp];
        
        [newResp release];
        
        
    }
}

- (NSMutableArray*)responsesForURL:(NSURL*)url{
    
    NSMutableArray* resp = [self.responses objectForKey:[url absoluteString]];
    
    if(resp == nil){
        
        resp = [NSMutableArray array];
        [self.responses setObject:resp forKey:[url absoluteString]];
        
    }
    
    return resp;

}

- (FJImageCacheResponse*)responseForURL:(NSURL*)url object:(id)object{
    
    NSMutableArray* r = [self responsesForURL:url];

    NSInteger index = [r indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:^(id obj, NSUInteger idx, BOOL *stop) {
        
        FJImageCacheResponse* resp = (FJImageCacheResponse*)obj;
        
        if([resp.requester isEqual:object]){
            
            *stop = YES;
            return YES;
        }
        
        return NO;
    }];
    
    if(index != NSNotFound){
        
        return [r objectAtIndex:index];
    }
    
    return nil;    
}



@end
