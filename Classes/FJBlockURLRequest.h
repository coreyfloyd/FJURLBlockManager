
#import <Foundation/Foundation.h>

@class FJBlockURLManager;

@protocol FJBlockURLRequestHeaderProvider;
@protocol FJBlockURLRequestResponseFormatter;


typedef void (^FJNetworkResponseHandler)(id response);
typedef void (^FJNetworkErrorHandler)(NSError* error);
typedef void (^FJNetworkUploadHandler)(int bytesSent, int totalBytes);
typedef void (^FJNetworkIncrementalResponseHandler)(id data, int bytesReceived, int totalBytes);

typedef enum  {
    FJBlockURLStatusNone,       //initialized, but not currently being "managed"
    FJBlockURLStatusScheduled,  //are we scheduled for download?
    FJBlockURLStatusRunning,    //are we working?
    FJBlockURLStatusFinished,   //are we done?
    FJBlockURLStatusCancelled,  //are we cancelled?
    FJBlockURLStatusError       //ruroh!
}FJBlockURLStatusType;


@interface FJBlockURLRequest : NSMutableURLRequest {
    
}


//Config Request Headers
@property (nonatomic, assign) id<FJBlockURLRequestHeaderProvider> headerProvider; //configures HTTP header(s) for the request. Useful for things like OAuth, if you prefer you can set headers manually

@property (nonatomic, retain) NSURL* uploadFileURL; //send large files directly from disk, you will still need to set the Content-Length field if required by the endpoint

//Response Behavior
@property (nonatomic, assign) BOOL retainAndAppendResponseData; //uses the internal responseData property to hold data received from the connection. If you turn this off, you MUST to implement the incrementalResponseBlock to handle data as it is recieved.  default = YES

@property (nonatomic) int maxAttempts; //how many retries before failure, default = 3;

@property (nonatomic, assign) BOOL cacheResponse; //default = YES. This determines whether or not the response will be cached. You should still use setCachePolicy method of NSMutableURLRequest to determine whether the cache is used to fulfil the request

@property (nonatomic, retain, readonly) NSMutableIndexSet* acceptedResponseCodes; //which response codes should we accept, default = 2XX range


//Callback blocks
@property (nonatomic) dispatch_queue_t responseQueue; //queue that the following blocks are called on, default = main queue

@property (nonatomic, copy) dispatch_block_t requestStartedBlock; //request started, don't mutate the request at this point 

@property (nonatomic, copy) FJNetworkUploadHandler uploadProgressBlock; //called throughout the upload process

@property (nonatomic, copy) FJNetworkIncrementalResponseHandler incrementalResponseBlock; //called each time data is downloaded

@property (nonatomic, copy) FJNetworkResponseHandler completionBlock; //called on success, data will be returned IFF retainAndAppendResponseData = YES

@property (nonatomic, copy) FJNetworkErrorHandler failureBlock; //called on failure, when attempt == maxAttempts


//Response
@property (nonatomic, retain, readonly) NSHTTPURLResponse *HTTPResponse; //access headers, etc if needed
@property (readonly) NSUInteger responseCode; 

@property (nonatomic, readonly) long long expectedResponseDataLength; //as reported by the HTTPResponse
@property (nonatomic, readonly) long long responseDataLength; //currrent length of downloade data

@property (nonatomic, retain, readonly) NSMutableData *responseData; //result if retainAndAppendResponseData is set to YES

@property (nonatomic, assign) id<FJBlockURLRequestResponseFormatter> responseFormatter; //not guranteed which thread/queue this will be accessed on
@property (nonatomic, retain, readonly) id formattedResponse; //result after it has been forrmated by the response formatter, if provided



//Request
- (void)schedule; //schedules with the defualt manager, retains! ([FJBlockURLManager defaultManager])
- (void)scheduleWithNetworkManager:(FJBlockURLManager*)networkManager; //same, but on a manger of your choice

//note: attempting to schedule a request on multiple managers is unsupported and will raise an exception, however, you can reuse the request after it has been completed

- (void)cancel; //cancels request, note: failureblock will be called with cancelled error code


//Other in-flight info
@property (readonly) int attempt; //which attempt is this?

@property (readonly) FJBlockURLStatusType status; //what is going on here?

@property (nonatomic, assign, readonly) FJBlockURLManager *manager; //on which manager is this request scheduled?

@end




//used to configure headers for purposes such as OAuth
@protocol FJBlockURLRequestHeaderProvider <NSObject>

@required
- (void)setHeaderFieldsForRequest:(FJBlockURLRequest*)request; //called just before the request is started

@end

//format responses 
@protocol FJBlockURLRequestResponseFormatter <NSObject>

@required
- (id)formatResponse:(id)response;

@optional
@property (nonatomic, retain) id<FJBlockURLRequestResponseFormatter, NSObject> nextFormatter; //use this to pass to the next formatter in the chain for unlimited fun!


@end



