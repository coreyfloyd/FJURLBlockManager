

#import "DemoErrorResponseFormatter.h"

@implementation DemoErrorResponseFormatter


- (id)formatResponse:(id)response{
    
    NSString* status = [response objectForKey:@"stat"];
    
    if(![status isEqualToString:@"ok"]){
        
        NSDictionary* errorDict = [response objectForKey:@"err"];
        
        NSString* errorCode = [errorDict objectForKey:@"code"];

        return [NSError errorWithDomain:@"kDemoErrorDomain" code:[errorCode intValue] userInfo:errorDict];
        
    }
    
    return response;
}


@end
