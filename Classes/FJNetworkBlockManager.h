#import <Foundation/Foundation.h>

@class FJBlockURLRequest;

typedef enum  {
    FJNetworkBlockManagerQueue, //FIFO
    FJNetworkBlockManagerStack  //FILO
} FJNetworkBlockManagerType;


@interface FJNetworkBlockManager : NSObject {
    
    dispatch_queue_t managerQueue;
    FJNetworkBlockManagerType type;
    
    BOOL idle;
}


@property (nonatomic) FJNetworkBlockManagerType type;       //default = queue
@property (nonatomic) NSInteger maxConcurrentRequests;      //default = 2
@property (nonatomic) NSInteger maxScheduledRequests;       //default = 100 
@property (nonatomic) BOOL idle;                            //KVO to know when ALL work is complete, if so inclined


+ (FJNetworkBlockManager*)defaultManager;

- (void)cancelAllRequests;


@end
