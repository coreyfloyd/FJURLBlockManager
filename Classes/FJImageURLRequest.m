//
//  ImageURLRequest.m
//  Vimeo
//
//  Created by Corey Floyd on 8/8/10.
//  Copyright 2010 Flying Jalapeño. All rights reserved.
//

#import "FJImageURLRequest.h"

float const totalCacheSizeInMB = 2.0;


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


@interface FJBlockURLRequest(ImageURLRequest)

@property (nonatomic, readwrite) dispatch_queue_t workQueue;

@end



@interface FJImageURLRequest()

@property (nonatomic, retain) NSCache *imageCache;
@property (nonatomic) NSUInteger observerCount; 


+ (NSCache*)sharedImageCache;
+ (UIImage*)imageForURL:(NSURL*)url;
+ (void)setImage:(UIImage*)image forURL:(NSURL*)url;

+ (void)setRequest:(FJImageURLRequest*)request forURL:(NSURL*)url;
+ (FJImageURLRequest*)requestForURL:(NSURL*)url;

@end


static NSCache* _imageCache = nil;


@implementation FJImageURLRequest

@synthesize imageCache;
@synthesize imageBlock;
@synthesize useMemoryCache;
@synthesize useDiskCache;
@synthesize observerCount;

+ (void)load{
    
    createImagesDirectory();
}

+ (NSCache*)sharedImageCache{
    
    if(_imageCache == nil){
        
        _imageCache = [[NSCache alloc] init];
        
        [_imageCache setName:@"ImageURLCache"];
        
        float cacheSizeFloat = floorf(131072 * totalCacheSizeInMB);
        
        ASSERT_TRUE(cacheSizeFloat < NSUIntegerMax);
        ASSERT_TRUE(cacheSizeFloat > 0);

        NSUInteger cacheSize = (NSUInteger)cacheSizeFloat; 
        
        [_imageCache setTotalCostLimit:cacheSize];
    }
    
    return _imageCache;
}

+ (UIImage*)imageForURL:(NSURL*)url{
    
    return [[self sharedImageCache] objectForKey:[url absoluteString]];
    
}

+ (void)setImage:(UIImage*)image forURL:(NSURL*)url{
    
    //TODO: nil/null/0 checking
    
    size_t bytesperRow = CGImageGetBytesPerRow(image.CGImage);
    size_t rows = CGImageGetHeight(image.CGImage);
    size_t bytes = rows * bytesperRow; 
    
    [[self sharedImageCache] setObject:image forKey:[url absoluteString] cost:bytes];
}



+ (id)imageRequestWithURL:(NSURL*)imageURL{
    
    FJImageURLRequest* r = [self requestForURL:imageURL];
    
    
    if(r == nil){
        r = [[FJImageURLRequest alloc] initWithURL:imageURL];
        [self setRequest:r forURL:imageURL];
        
        [r autorelease];
    }
    
    //TODO: osatomicincrement?
    r.observerCount = r.observerCount+1;
    
    return r;
}

- (id)initWithURL:(NSURL*)url{
    
    if ((self = [super initWithURL:url])) {

        self.useDiskCache = YES;
        self.useMemoryCache = YES;
    }
    
    return self;
}

+ (void)setRequest:(FJImageURLRequest*)request forURL:(NSURL*)url{
    
    [self associateValue:request withKey:[url absoluteString]];
    
}

+ (FJImageURLRequest*)requestForURL:(NSURL*)url{
    
    return [self associatedValueForKey:[url absoluteString]];
    
}


- (void)scheduleWithNetworkManager:(FJBlockURLManager *)networkManager{
        
    UIImage* i = nil;
    
    //check mem cache
    if(useMemoryCache)
        i = [FJImageURLRequest imageForURL:[self URL]];

    if(i != nil && self.imageBlock){
                    
        dispatch_async(self.responseQueue, ^{
            
            self.imageBlock(i);
            
        });
        
        return;
    }
    
    //check disk cache
    if(useDiskCache)
        i = [UIImage imageWithContentsOfFile:imagePathForURL([self URL])];
    
    if(i != nil){
        
        if(self.imageBlock){
            
            dispatch_async(self.responseQueue, ^{
                
                self.imageBlock(i);
                
            });
        }
       
        //cache to mem
        dispatch_async(self.workQueue, ^{
            
            [FJImageURLRequest setImage:i forURL:[self URL]];
            
        });           
        
        return;
    }
    
    //image doesn't exist, set response block
    self.completionBlock = ^(NSData* response){
        
        UIImage* i = [UIImage imageWithData:response];
        
        if(i == nil){
            
            NSError* error = [NSError corruptImageResponse:[self URL] data:response];
            
            if(self.failureBlock)
                self.failureBlock(error);    
            
            return;
        }
        
        //return image
        if(self.imageBlock)
            self.imageBlock(i);
        
        //cache in mem
        dispatch_async(self.workQueue, ^{
            
            [FJImageURLRequest setImage:i forURL:[self URL]];
            
        });      
        
        //cache in disk
        dispatch_async(self.workQueue, ^{
            
            NSString* path = imagePathForURL([self URL]);
            
            if(![response writeToFile:path atomically:YES]){
                
                ALWAYS_ASSERT;
                //TODO: handle write error
                
            }    
            
        });       
    };
    
    [super scheduleWithNetworkManager:networkManager];
    
}

- (void)cancel{
    
    self.observerCount = self.observerCount - 1;
    
    if(observerCount < 1)
        [super cancel];    
    
}

@end
