
#import "FJImageCacheManager.h"
#import "FJNetworkBlockManager.h"
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


static FJImageCacheManager* _defaultManager = nil;


@interface FJImageCacheManager()

@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic, retain) FJNetworkBlockManager *networkManager;
@property (nonatomic, retain) NSMutableDictionary *imageURLs;

@end


@implementation FJImageCacheManager

@synthesize managerQueue;
@synthesize networkManager;
@synthesize imageURLs;

- (void) dealloc
{
    [networkManager release];
    networkManager = nil;
    [imageURLs release];
    imageURLs = nil;
    [super dealloc];
}


+(FJImageCacheManager*)defaultManager{
    
    if(_defaultManager == nil){
        _defaultManager = [[FJImageCacheManager alloc] init];
    }
    
    return _defaultManager;
}


- (id) init
{
    self = [super init];
    if (self != nil) {
        
        NSString* queueName = [NSString stringWithFormat:@"com.FJImageCacheManager.%i", [self hash]];
        self.managerQueue = dispatch_queue_create([queueName UTF8String], NULL);
        self.networkManager = [[[FJNetworkBlockManager alloc] init] autorelease]; 
        self.imageURLs = [NSMutableDictionary dictionaryWithCapacity:10];
        
        createImagesDirectory();
    }
    return self;
}



- (void)fetchImageAtURL:(NSURL*)imageURL                            
         respondOnQueue:(dispatch_queue_t)queue                     
        completionBlock:(void(^)(UIImage* image))completionBlock    
           failureBlock:(void(^)(NSError* error))errorBlock{
    
    UIImage* i = [UIImage imageWithContentsOfFile:imagePathForURL(imageURL)];
    
    if(i != nil){
        
        dispatch_async(queue,  ^{
            
            completionBlock(i);
            
        });     
        
        return;
    }
    
    
    NSURLRequest* request = [NSURLRequest requestWithURL:imageURL];
    
    [self.imageURLs setObject:request forKey:imageURL];
    
    [self.networkManager sendRequest:request 
                      respondOnQueue:self.managerQueue 
                     completionBlock:^(NSData* result){
                                        
                         UIImage* i = [UIImage imageWithData:result];
                         
                         dispatch_async(queue,  ^{
                             
                             completionBlock(i);
                             
                         });
                         
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
                                                                       
                         dispatch_async(queue,  ^{
                             
                             errorBlock(error);
                             
                         });
                         
                         
                         //TODO: cleanup


                     }];

}        

- (void)cancelFetchAtURL:(NSURL*)imageURL{
    
    NSURLRequest* req = [self.imageURLs objectForKey:imageURL];
    
    [self.networkManager cancelRequest:req];
    
    [self.imageURLs removeObjectForKey:imageURL];
    
}

- (void)cancelAllRequests{
    
    [self.networkManager cancelAllRequests];
    
}

@end
