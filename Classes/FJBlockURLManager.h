#import <Foundation/Foundation.h>

@class FJBlockURLRequest;

typedef enum  {
    FJNetworkBlockManagerQueue, //FIFO
    FJNetworkBlockManagerStack  //FILO
} FJNetworkBlockManagerType;


@interface FJBlockURLManager : NSObject {
    
}
+ (FJBlockURLManager*)defaultManager;

//info
@property (nonatomic, readonly) BOOL idle;                            //KVO to know when ALL work is complete, if so inclined


//config
@property (nonatomic) FJNetworkBlockManagerType type;       //default = queue
@property (nonatomic) NSInteger maxConcurrentRequests;      //default = 4
@property (nonatomic) NSInteger maxScheduledRequests;       //default = 100 


//Suspend
//requests in motion will stay in motion, even when acted upon by an outside force (you)
//all suspends must be balanced with a resume (increment/decrement)
- (void)suspend; 
- (void)resume;


//Kill them all, will stop requests in motion
- (void)cancelAllRequests;


@end
