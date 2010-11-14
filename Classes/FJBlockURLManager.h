#import <Foundation/Foundation.h>

@class FJBlockURLRequest;

typedef enum  {
    FJNetworkBlockManagerQueue, //FIFO
    FJNetworkBlockManagerStack  //FILO
} FJNetworkBlockManagerType;


@interface FJBlockURLManager : NSObject {
    
}
+ (FJBlockURLManager*)defaultManager; //default = queue, 4, NSIntegerMax
+ (void)setDefaultManager:(FJBlockURLManager*)aManager;

- (id)initWithType:(FJNetworkBlockManagerType)aType concurrentRequests:(NSInteger)concurrent scheduledRequests:(NSInteger)scheduled;

//info
@property (nonatomic, readonly) BOOL idle;                               //KVO to know when ALL work is complete, if so inclined
@property (nonatomic, retain, readonly) NSArray* allRequests;            //get all requests, non observable

@property (nonatomic, readonly) FJNetworkBlockManagerType type;       
@property (nonatomic, readonly) NSInteger maxConcurrentRequests;      
@property (nonatomic, readonly) NSInteger maxScheduledRequests;        


//Suspend
//requests in motion will stay in motion, even when acted upon by an outside force (you)
//meaning: a request in progress will continue, but no other requests will be started until the manager is resumed.
//all suspends must be balanced with a resume (increment/decrement)
- (void)suspend; 
- (void)resume;


//Cancel all requests including those in progress
- (void)cancelAllRequests;


@end
