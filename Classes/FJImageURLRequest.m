//
//  ImageURLRequest.m
//  Vimeo
//
//  Created by Corey Floyd on 8/8/10.
//  Copyright 2010 Flying Jalapeño. All rights reserved.
//

#import "FJImageURLRequest.h"

float const totalCacheSizeInMB = 5.0;

static NSString* folderName = @"Images";

#pragma mark Functions


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

BOOL deleteImagesDirectory()
{
        
    return [[NSFileManager defaultManager] removeItemAtPath:imageDirectoryPath() error:nil];

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

BOOL deleteImageAtPath(NSString* path){
	
	return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];;
}

BOOL writeImageToFile(UIImage* image, NSString* path){
    
    NSData* imageData = UIImagePNGRepresentation(image); 
	
    deleteImageAtPath(path);
    		
	return [imageData writeToFile:path atomically:YES];

}





#pragma mark -
#pragma mark FJBlockURLRequest Private Interface

@interface FJBlockURLRequest(ImageURLRequest)

@property (nonatomic, readwrite) dispatch_queue_t workQueue;

@end


#pragma mark -
#pragma mark FJImageURLRequest Private Interface

@class FJMasterImageBlockRequest;

@interface FJImageURLRequest()

@property (nonatomic, readwrite) FJMasterImageBlockRequest* masterRequest;
- (id)initWithMasterRequest:(FJMasterImageBlockRequest*)masterReq;

@end



#pragma mark -
#pragma mark FJMasterBlockRequest

static NSCache* _imageCache = nil;


@interface FJMasterImageBlockRequest : FJBlockURLRequest
{
    
}

@property (nonatomic, readwrite, retain) NSMutableArray* subRequests;


+ (FJMasterImageBlockRequest*)requestForURL:(NSURL*)url;

- (void)cancelSubRequest:(FJImageURLRequest*)req;


+ (NSCache*)sharedImageCache;
+ (void)flushImageCache;
+ (void)cacheImage:(UIImage*)image forURL:(NSURL*)url;
+ (UIImage*)cachedImageForURL:(NSURL*)url;

+ (void)saveImage:(UIImage*)image withURL:(NSURL*)url;
+ (UIImage*)savedImageForURL:(NSURL*)url;


@end


@implementation FJMasterImageBlockRequest

@synthesize subRequests;


+ (void)load{
    
    NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
    
    createImagesDirectory();
    
    [p drain];
}


#pragma mark Requests

+ (void)setRequest:(FJMasterImageBlockRequest*)request forURL:(NSURL*)url{
    
    [self associateValue:request withKey:[url absoluteString]];
    
}



+ (FJMasterImageBlockRequest*)requestForURL:(NSURL*)url{
    
    FJMasterImageBlockRequest* r = [self associatedValueForKey:[url absoluteString]];
    
    if(r == nil){
        r = [[FJMasterImageBlockRequest alloc] initWithURL:url];
        [self setRequest:r forURL:url];
        
        [r autorelease];
    }
    
    return r;
    
}


#pragma mark NSObject


- (id)initWithURL:(NSURL*)url{
    
    if ((self = [super initWithURL:url])) {
        
        self.subRequests = [NSMutableArray array];
    }
    
    return self;
}


#pragma mark schedule

- (void)scheduleWithNetworkManager:(FJBlockURLManager *)networkManager{
    
    if(self.inProcess)
        return;
    
    self.responseQueue = self.workQueue;
    
    //create image block
    self.completionBlock = ^(NSData* response){
        
        UIImage* i = [UIImage imageWithData:response];
        
        
        //handle unparsed image
        if(i == nil){
            
            NSError* error = [NSError corruptImageResponse:[self URL] data:response];
            
            for(FJImageURLRequest* each in self.subRequests){
                
                FJNetworkErrorHandler e = [each failureBlock];
                
                if(e){
                    
                    dispatch_async(each.responseQueue, ^{
                        e(error);
                    });
                }
                
                //remeove finished subrequest
                [self cancelSubRequest:each];
            }
            
            [FJMasterImageBlockRequest setRequest:nil forURL:[self URL]];
            
            return;
        }
        
        //return image
        for(FJImageURLRequest* each in self.subRequests){
            
            FJImageResponseHandler r = [each imageBlock];
            
            if(r){
                
                dispatch_async(each.responseQueue, ^{
                    r(i);
                });
            }
            
            //remeove finished subrequest
            [self cancelSubRequest:each];
        }
        
        
        //cache in mem
        dispatch_async(self.workQueue, ^{
            
            [FJMasterImageBlockRequest cacheImage:i forURL:[self URL]];
            
        });      
        
        //cache in disk
        dispatch_async(self.workQueue, ^{
            
            [FJMasterImageBlockRequest saveImage:i withURL:[self URL]];
            
        }); 
        
        //remove finished request
        [FJMasterImageBlockRequest setRequest:nil forURL:[self URL]];

    };
    
    
    
    
    //create error block
    self.failureBlock = ^(NSError* error){
        
      for(FJImageURLRequest* each in self.subRequests){
          
          FJNetworkErrorHandler e = [each failureBlock];
          
          if(e){
              
              dispatch_async(each.responseQueue, ^{
                  e(error);
              });
              
          }
          
          //remeove finished subrequest
          [self cancelSubRequest:each];
      }
        //remove finished request
        [FJMasterImageBlockRequest setRequest:nil forURL:[self URL]];

    };
    
    debugLog(@"Master Image URL request scheduled: %@", [[self URL] description]);
    
    [super scheduleWithNetworkManager:networkManager];
    
}


- (void)cancel{
    
    if([[self subRequests] count] == 0)
        [super cancel];
    
}


- (void)cancelSubRequest:(FJImageURLRequest*)req{
    
    req.masterRequest = nil;
    
    int i = [self.subRequests indexOfObject:req];
    
    if(i == NSNotFound){
        ALWAYS_ASSERT;
    }
    
    [self.subRequests removeObjectAtIndex:i];
    
    [self cancel];
    
}

#pragma mark Image Cache

+ (NSCache*)sharedImageCache{
    
    if(_imageCache == nil){
        
        _imageCache = [[NSCache alloc] init];
        
        [_imageCache setName:@"ImageURLCache"];
        
        float cacheSizeFloat = floorf(1048576 * totalCacheSizeInMB);
        
        ASSERT_TRUE(cacheSizeFloat < NSUIntegerMax);
        ASSERT_TRUE(cacheSizeFloat > 0);
        
        NSUInteger cacheSize = (NSUInteger)cacheSizeFloat; 
        
        [_imageCache setTotalCostLimit:cacheSize];
    }
    
    return _imageCache;
}

+ (void)flushImageCache{
    
    [[self sharedImageCache] removeAllObjects];
    
}

+ (UIImage*)cachedImageForURL:(NSURL*)url{
    
    return [[self sharedImageCache] objectForKey:[url absoluteString]];
    
}

+ (void)cacheImage:(UIImage*)image forURL:(NSURL*)url{
    
    //TODO: nil/null/0 checking
    //TODO: are bytes of UIImage in mem larger than on disk due to compression? (JPEG or PNG), the bytes calculated her are roughly 10x bigger than the size reported by the finder

    size_t bytesperRow = CGImageGetBytesPerRow(image.CGImage);
    size_t rows = CGImageGetHeight(image.CGImage);
    size_t bytes = rows * bytesperRow; 
        
    [[self sharedImageCache] setObject:image forKey:[url absoluteString] cost:bytes];
    
}


+ (UIImage*)savedImageForURL:(NSURL*)url{
    
    return [UIImage imageWithContentsOfFile:imagePathForURL(url)];
    
}

+ (void)saveImage:(UIImage*)image withURL:(NSURL*)url{
    
    NSString* path = imagePathForURL(url);
    
    if(!writeImageToFile(image, path)){
        
        ALWAYS_ASSERT;
        //TODO: handle write error
        
    }        
}


+ (void)deleteImageFileForURL:(NSURL*)url{
    
    deleteImageAtPath(imagePathForURL(url));
    
}
+ (void)deleteAllImageFiles{
    
    deleteImagesDirectory();
    createImagesDirectory();
    
}

@end





#pragma mark -
#pragma mark FJImageURLRequest


@implementation FJImageURLRequest

@synthesize imageBlock;
@synthesize useMemoryCache;
@synthesize useDiskCache;
@synthesize masterRequest;

#pragma mark -
#pragma mark Initialize

+ (id)requestWithURL:(NSURL*)url{
    
    FJMasterImageBlockRequest* r = [FJMasterImageBlockRequest requestForURL:url];

    FJImageURLRequest* newReq = [[FJImageURLRequest alloc] initWithMasterRequest:r];
    
    [r.subRequests addObject:newReq];
    
    return [newReq autorelease];
}

- (id)initWithMasterRequest:(FJMasterImageBlockRequest*)masterReq{
    
    if ((self = [super initWithURL:[masterReq URL]])) {
        
        self.useDiskCache = YES;
        self.useMemoryCache = YES;
        self.masterRequest = masterReq;
    }
    
    return self;
    
}


- (void)scheduleWithNetworkManager:(FJBlockURLManager *)networkManager{
    
    //just in case out master request was lost, or we were rescheduled
    
    self.masterRequest = [FJMasterImageBlockRequest requestForURL:[self URL]];
    
    
    
    UIImage* i = nil;
    
    //check mem cache
    if(useMemoryCache)
        i = [FJMasterImageBlockRequest cachedImageForURL:[self URL]];

    if(i != nil && self.imageBlock){
        
        dispatch_async(self.responseQueue, ^{
            
            self.imageBlock(i);
            
        });
        
        [self cancel];

        return;
    }

    
    
    
    
    
    //check disk cache
    if(useDiskCache)
        i = [FJMasterImageBlockRequest savedImageForURL:[self URL]];

    
    if(i != nil){
        
        if(self.imageBlock){
            
            dispatch_async(self.responseQueue, ^{
                
                self.imageBlock(i);
                
            });
        }
       
        //cache to mem
        dispatch_async(self.workQueue, ^{
            
            [FJMasterImageBlockRequest cacheImage:i forURL:[self URL]];
            
        }); 
        
        [self cancel];
        
        return;
    }
    
    
    
    //we missed the memory and disk cache, so we really need to feetch. forward fetching to master request
    debugLog(@"Delegating scheduling of URL to master request: %@", [[self URL] description]);
    [self.masterRequest scheduleWithNetworkManager:networkManager];
        
}

- (void)cancel{
    
    [self.masterRequest cancelSubRequest:self];
    
}


#pragma mark -
#pragma mark Image Cache

+ (void)flushImageCache{
    
    [FJMasterImageBlockRequest flushImageCache];
    
}

+ (void)deleteImageFileForURL:(NSURL*)url{
    
    [FJMasterImageBlockRequest deleteImageFileForURL:url];
    
}
+ (void)deleteAllImageFiles{
    
    [FJMasterImageBlockRequest deleteAllImageFiles];
    
}



@end
