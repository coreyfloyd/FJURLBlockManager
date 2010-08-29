//
//  FJJSONResponseFormatter.m
//  Vimeo
//
//  Created by Corey Floyd on 8/25/10.
//  Copyright 2010 Flying Jalapeño. All rights reserved.
//

#import "FJJSONResponseFormatter.h"
#import "JSONKit.h"

@implementation FJJSONResponseFormatter

@synthesize nextFormatter;

- (void) dealloc
{
    
    [nextFormatter release];
    nextFormatter = nil;
    [super dealloc];
}


- (id)formatResponse:(id)response{
    
    if(response == nil)
        return nil;
    
    NSString* responseString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    
    debugLog(@"recieved jsonString: %@", responseString);
    
    NSError* error = nil;
    
    id jsonObject = nil;
    
    if(responseString != nil && ![responseString isEmpty]){
        
        @try {
            
            jsonObject = [NSObject objectWithJSON:responseString];
        }
        @catch (NSException * e) {
            
            error = [NSError JSONParseErrorWithData:responseString];
            
            return error;
        }
    }
    
    id finalResponse = jsonObject;
    
    if(nextFormatter != nil)
        finalResponse = [nextFormatter formatResponse:finalResponse];
    
    return finalResponse;
}


@end
