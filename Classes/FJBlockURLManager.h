#import <Foundation/Foundation.h>

@class FJBlockURLRequest;

typedef enum  {
    FJNetworkBlockManagerQueue, //FIFO
    FJNetworkBlockManagerStack  //FILO
} FJNetworkBlockManagerType;


@interface FJBlockURLManager : NSObject {
    
    dispatch_queue_t managerQueue;
    FJNetworkBlockManagerType type;
    
    BOOL idle;
}


@property (nonatomic) FJNetworkBlockManagerType type;       //default = queue
@property (nonatomic) NSInteger maxConcurrentRequests;      //default = 2
@property (nonatomic) NSInteger maxScheduledRequests;       //default = 100 
@property (nonatomic) BOOL idle;                            //KVO to know when ALL work is complete, if so inclined
@property (nonatomic, readonly) BOOL suspended;             


+ (FJBlockURLManager*)defaultManager;

- (void)suspend; //requests in motion will stay in motion, even when acted upon by an outside force (you)
- (void)resume;

- (void)cancelAllRequests;


@end
