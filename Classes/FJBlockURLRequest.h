//
//  FJBlockURLRequest.h
//  FJNetworkBlockManager
//
//  Created by Corey Floyd on 7/24/10.
//  Copyright (c) 2010 Flying Jalapeño. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJNetworkBlockManager.h"

@interface FJBlockURLRequest : NSObject {

    NSURLRequest* request;
    
    NSThread* connectionThread;
    NSURLConnection* connection;
    
    dispatch_queue_t requestQueue;
    NSMutableData* responseData;
    BOOL inProcess;
    int attempt;
    
    dispatch_queue_t completionQueue;
    FJNetworkResponseHandler completionBlock;
    FJNetworkErrorHandler failureBlock;

}
@property (nonatomic, retain) NSThread *connectionThread;
@property (nonatomic) dispatch_queue_t requestQueue;
@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic) dispatch_queue_t completionQueue;
@property (nonatomic, copy) FJNetworkResponseHandler completionBlock;
@property (nonatomic, copy) FJNetworkErrorHandler failureBlock;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic) BOOL inProcess;
@property (nonatomic) int attempt;



- (id)initWithRequest:(NSURLRequest*)req
     connectionThread:(NSThread*)thread
      completionQueue:(dispatch_queue_t)queue       //can be nil, defaults to main queue
      completionBlock:(FJNetworkResponseHandler)completion 
         failureBlock:(FJNetworkErrorHandler)failure;        

- (void)start;
- (void)cancel;



@end
