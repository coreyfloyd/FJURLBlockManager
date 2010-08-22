/*
 Since both memory and disk caching are implemented, NSURL caching is disabled by defualt (unlike the superclass FJBlockURLConnection)
 i.e. self.cacheResponse = NO;
*/

#import "FJBlockURLRequest.h"

typedef void (^FJImageResponseHandler)(UIImage* image);

@interface FJImageURLRequest : FJBlockURLRequest {
    
}
@property (nonatomic, copy) FJImageResponseHandler imageBlock; //dispatched on success. Use this instead of the request.completionBlock

@property (nonatomic) BOOL useMemoryCache; //default = YES
@property (nonatomic) BOOL useDiskCache; //default = YES

//only use this convienence initializer
+ (id)requestWithURL:(NSURL*)url;



//caches management
+ (void)flushImageCache;

+ (void)deleteImageFileForURL:(NSURL*)url;
+ (void)deleteAllImageFiles;


@end
