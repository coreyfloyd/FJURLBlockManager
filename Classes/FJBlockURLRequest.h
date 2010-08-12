
#import <Foundation/Foundation.h>

@class FJBlockURLManager;

typedef void (^FJNetworkResponseHandler)(NSData* response);
typedef void (^FJNetworkErrorHandler)(NSError* error);

extern NSString* const FJBlockURLErrorDomain;

typedef enum  {
    
    FJBlockURLErrorNone = 0,
    FJBlockURLErrorCancelled
    
} FJBlockURLErrorCode;


@interface FJBlockURLRequest : NSMutableURLRequest {
    
    
}

//Use
- (void)schedule; //schedules with the defualt manager, retains!
- (void)scheduleWithNetworkManager:(FJBlockURLManager*)networkManager; //same, but on a manger of your choice

- (void)cancel;


//Config
@property (nonatomic, copy) FJNetworkResponseHandler completionBlock; //called on success
@property (nonatomic, copy) FJNetworkErrorHandler failureBlock; //called on failure, when attempt = maxAttempts

@property (nonatomic) dispatch_queue_t responseQueue; //queue that completion/failure blocks are called on, default = main queue

@property (nonatomic, retain) NSMutableData *responseData; //result

@property (nonatomic) int maxAttempts; //how many retries before failure, default = 3;

@property (nonatomic, assign, readonly) FJBlockURLManager *manager; //should this run on a specific manager, defualt = [FJBlockURLManager defaultManager]


//info
@property (readonly) BOOL isScheduled; //are we scheduled for download?

@property (readonly) BOOL inProcess; //are we working?
@property (readonly) BOOL isFinished; //are we done?

@property (readonly) int attempt; //is this the first attempt?



@end
