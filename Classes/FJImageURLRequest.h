
#import "FJBlockURLRequest.h"

typedef void (^FJImageResponseHandler)(UIImage* image);

@interface FJImageURLRequest : FJBlockURLRequest {
    
}
@property (nonatomic, copy) FJImageResponseHandler imageBlock; //dispatched on success. Use this instead of the request.completionBlock

@property (nonatomic) BOOL useMemoryCache; //default = YES
@property (nonatomic) BOOL useDiskCache; //default = YES

//only use these initializers
+ (id)requestWithURL:(NSURL*)url;
- (id)initWithURL:(NSURL*)url; //NSURL caching is disabled by defualt (unlike the superclass FJBlockURLConnection)


//caches management
+ (void)flushImageCache;

+ (void)deleteImageFileForURL:(NSURL*)url;
+ (void)deleteAllImageFiles;


@end
