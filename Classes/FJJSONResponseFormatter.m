
#define USE_JSON_KIT

#import "FJJSONResponseFormatter.h"
#import "JSONKit.h"
//#import "SBJSON.h"

@implementation FJJSONResponseFormatter

@synthesize nextFormatter;

- (void) dealloc
{
    
    [nextFormatter release];
    nextFormatter = nil;
    [super dealloc];
}

#ifdef USE_JSON_KIT

- (id)formatResponse:(id)response{
    
    if(response == nil)
        return nil;
    
    NSString* responseString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    
    extendedDebugLog(@"recieved jsonString: %@", responseString);
    
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

#else

- (id)formatResponse:(id)response{
    
    if(response == nil)
        return nil;
    
    NSString* responseString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    
    extendedDebugLog(@"recieved jsonString: %@", responseString);
    
    NSError* error = nil;
    
    id jsonObject = nil;
    
    if(responseString != nil && ![responseString isEmpty]){
        
        SBJSON* sb = [[SBJSON alloc] init];
        jsonObject = [sb objectWithString:responseString error:&error];
        [sb release];
            
        if(jsonObject == nil)
            return error;
    }
    
    id finalResponse = jsonObject;
    
    if(nextFormatter != nil)
        finalResponse = [nextFormatter formatResponse:finalResponse];
    
    return finalResponse;
}

#endif

@end
