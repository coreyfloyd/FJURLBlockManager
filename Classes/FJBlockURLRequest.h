//
//  FJBlockURLRequest.h
//  FJNetworkBlockManager
//
//  Created by Corey Floyd on 7/24/10.
//  Copyright (c) 2010 Flying Jalapeño. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FJNetworkBlockManager;

typedef void (^FJNetworkResponseHandler)(NSData* response);
typedef void (^FJNetworkErrorHandler)(NSError* error);


@interface FJBlockURLRequest : NSURLRequest {
    
    
}

//Use
- (void)schedule;
- (void)scheduleWithNetworkManager:(FJNetworkBlockManager*)networkManager;

- (void)cancel;


//Config
@property (nonatomic, copy) FJNetworkResponseHandler completionBlock; //called on success
@property (nonatomic, copy) FJNetworkErrorHandler failureBlock; //called on failure, when attempt = maxAttempts

@property (nonatomic) dispatch_queue_t responseQueue; //queue that blocaks are called on, default = main queue

@property (nonatomic, retain) NSMutableData *responseData; //result

@property (nonatomic) int maxAttempts; //how many retries, default = 3;

@property (nonatomic, assign) FJNetworkBlockManager *manager; //should this run on a specific manager, defualt = defaultManager


//info
@property (nonatomic, readonly) BOOL inProcess; //are we working?
@property (nonatomic, readonly) int attempt; //is this the first attempt?






@property (nonatomic, readonly) dispatch_queue_t workQueue; //need to make some changes, use this queue



@end
