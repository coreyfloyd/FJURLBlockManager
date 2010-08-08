
#import "FJBlockURLRequest.h"

typedef void (^FJImageResponseHandler)(UIImage* image);

@interface FJImageURLRequest : FJBlockURLRequest {
    
}
@property (nonatomic, copy) FJImageResponseHandler imageBlock; //dispatched on success. Use this instead of the request.completionBlock

@property (nonatomic) BOOL useMemoryCache; //default = YES
@property (nonatomic) BOOL useDiskCache; //default = YES

+ (id)imageRequestWithURL:(NSURL*)imageURL;


@end
