
#import <Foundation/Foundation.h>
#import "FJBlockURLManager.h"

typedef void (^FJImageResponseHandler)(UIImage* image);
typedef void (^FJImageErrorHandler)(NSError* error);


@interface FJImageCacheManager : NSObject {
    
    dispatch_queue_t managerQueue;
    FJBlockURLManager* networkManager;
    NSMutableDictionary* responses;
    NSMutableDictionary* requests;

    
}
+ (FJImageCacheManager*)defaultManager;                         //uses the default manager queue
- (id)init;                                                     //uses the default manager queue
- (id)initWithNetworkManager:(FJBlockURLManager*)manager;   //provide a specific manager


- (void)fetchImageAtURL:(NSURL*)imageURL                            //what do you want?
         respondOnQueue:(dispatch_queue_t)queue                     //if nil, main queue is used
        completionBlock:(FJImageResponseHandler)completionBlock     //called on success, nonnil
           failureBlock:(FJImageErrorHandler)errorBlock           //called on errors, nonnil (3 attempts made before error block is called)
      requestedByobject:(id)object;                                 //used for cancelltion

//convienence call. same as above, but defaults to main queue and is UNCANCELABLE
- (void)fetchImageAtURL:(NSURL*)imageURL                            
        completionBlock:(FJImageResponseHandler)completionBlock     
           failureBlock:(FJImageErrorHandler)errorBlock;           


//cancel a request
- (void)cancelRequestForURL:(NSURL*)imageURL object:(id)object;

//cancel them all!
- (void)cancelAllRequests;


@end
