
#import <Foundation/Foundation.h>

@class FJBlockURLManager;

@protocol FJBlockURLRequestHeaderProvider;
@protocol FJBlockURLRequestResponseFormatter;


typedef void (^FJNetworkResponseHandler)(id response);
typedef void (^FJNetworkErrorHandler)(NSError* error);

extern NSString* const FJBlockURLErrorDomain;

typedef enum  {
    
    FJBlockURLErrorNone = 0,
    FJBlockURLErrorCancelled
    
} FJBlockURLErrorCode;


@interface FJBlockURLRequest : NSMutableURLRequest {
    
    NSUInteger responseCode;
}

//Request
- (void)schedule; //schedules with the defualt manager, retains!
- (void)scheduleWithNetworkManager:(FJBlockURLManager*)networkManager; //same, but on a manger of your choice

- (void)cancel;

//Response
@property (nonatomic, retain, readonly) NSMutableData *responseData; //result
@property (nonatomic, retain, readonly) id formattedResponse; //result after it has been forrmated by the response formatter, if provided

@property (nonatomic, retain, readonly) NSHTTPURLResponse *HTTPResponse; //access headers, etc if needed
@property (readonly) NSUInteger responseCode; 


//Config
@property (nonatomic, copy) FJNetworkResponseHandler completionBlock; //called on success
@property (nonatomic, copy) FJNetworkErrorHandler failureBlock; //called on failure, when attempt = maxAttempts

@property (nonatomic) dispatch_queue_t responseQueue; //queue that completion/failure blocks are called on, default = main queue

@property (nonatomic) int maxAttempts; //how many retries before failure, default = 3;

@property (nonatomic, assign, readonly) FJBlockURLManager *manager; //should this run on a specific manager? defualt = [FJBlockURLManager defaultManager]

@property (nonatomic, assign) BOOL cacheResponse; //default = YES

@property (nonatomic, assign) id<FJBlockURLRequestHeaderProvider> headerDelegate; //configures HTTP header(s) for the request. Useful for things like OAuth

@property (nonatomic, retain) id<FJBlockURLRequestResponseFormatter> responseFormatter; //not guranteed which thread/queue this will be accessed on

@property (nonatomic, retain) NSMutableIndexSet* acceptedResponseCodes; //default = 199 > x > 299


//Info
//TODO: convert these 3 BOOLs into an enum
@property (readonly) BOOL isScheduled; //are we scheduled for download?

@property (readonly) BOOL inProcess; //are we working?
@property (readonly) BOOL isFinished; //are we done?

@property (readonly) int attempt; //is this the first attempt?



@end


@protocol FJBlockURLRequestHeaderProvider
@required
- (void)setHeaderFieldsForRequest:(FJBlockURLRequest*)request;

@end

//Chain these together for unlimited fun!
@protocol FJBlockURLRequestResponseFormatter
@required
- (id)formatResponse:(id)response;

@end



