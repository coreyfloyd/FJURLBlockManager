#import <Foundation/Foundation.h>


typedef void (^FJNetworkResponseHandler)(NSData* response);
typedef void (^FJNetworkErrorHandler)(NSError* error);

typedef enum  {
    FJNetworkBlockManagerQueue, //FIFO
    FJNetworkBlockManagerStack  //FILO
} FJNetworkBlockManagerType;


@interface FJNetworkBlockManager : NSObject {
    
    dispatch_queue_t managerQueue;
    FJNetworkBlockManagerType type;

    NSThread* requestThread;
    NSMutableArray* requests;
    NSMutableDictionary* requestMap;
    
    NSInteger maxConcurrentRequests;
    NSInteger maxRequestsInQueue;
    
    BOOL idle;
}

@property (nonatomic) FJNetworkBlockManagerType type;   //default = queue
@property (nonatomic) NSInteger maxConcurrentRequests;  //default = 2
@property (nonatomic) NSInteger maxRequestsInQueue;     //default = 100 
@property (nonatomic) BOOL idle;                        //KVO to know when ALL work is complete, if so inclined


+(FJNetworkBlockManager*)defaultManager;

- (void)sendRequest:(NSURLRequest*)req                          //what do you want?
     respondOnQueue:(dispatch_queue_t)queue                     //if nil, main queue is used
    completionBlock:(FJNetworkResponseHandler)completionBlock   //called on success, cannot be nil
       failureBlock:(FJNetworkErrorHandler)errorBlock;          //called on errors, cannot be nil (3 attempts made before error block is called)

- (void)cancelRequest:(NSURLRequest*)req;

- (void)cancelAllRequests;



@end
