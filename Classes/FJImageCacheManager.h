
#import <Foundation/Foundation.h>

@class FJNetworkBlockManager;

@interface FJImageCacheManager : NSObject {
    
    dispatch_queue_t managerQueue;
    FJNetworkBlockManager* networkManager;
    NSMutableDictionary* imageURLs;
    
}
+(FJImageCacheManager*)defaultManager;

- (void)fetchImageAtURL:(NSURL*)imageURL                            //what do you want?
         respondOnQueue:(dispatch_queue_t)queue                     //if nil, main queue is used
        completionBlock:(void(^)(UIImage* image))completionBlock    //called on success, nonnil
           failureBlock:(void(^)(NSError* error))errorBlock;        //called on errors, nonnil (3 attempts made before error block is called)

- (void)cancelFetchAtURL:(NSURL*)imageURL;

- (void)cancelAllRequests;

@end
