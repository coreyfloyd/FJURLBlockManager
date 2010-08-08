
#import "NSError+Vimeo.h"

NSString* const kVimeoErrorDomain = @"kVimeoErrorDomain";
NSString* const kUnparsedJSONStringKey = @"kUnparsedJSONStringKey";
NSString* const kInvalidResponseDataKey = @"kInvalidResponseDataKey";
NSString* const kCorruptImageResponseDataKey = @"kCorruptImageResponseDataKey";



@implementation NSError(Vimeo)

+ (NSError*)errorWithVimeoErrorResponseDictionary:(NSDictionary*)dict{
    
    NSString* errorCode = [dict objectForKey:@"code"];
    NSString* description = [dict objectForKey:@"msg"];

    NSDictionary* newDict = [NSDictionary dictionaryWithObjectsAndKeys:
                          description, NSLocalizedDescriptionKey, 
                          nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:[errorCode intValue] userInfo:newDict];
    
    return err;
}


+ (NSError*)vimeoErrorWithCode:(VimeoErrorType)type localizedDescription:(NSString*)desc{
     
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:desc, NSLocalizedDescriptionKey, nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:type userInfo:dict];
    
    return err;
    
}

+ (NSError*)nilNetworkRespnseErrorWithURL:(NSURL*)url{
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Empty response from server", NSLocalizedDescriptionKey, 
                          url, NSURLErrorKey, 
                          nil];   
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorNilNetworkResponse userInfo:dict];
    
    return err;
    
}

+ (NSError*)JSONParseErrorWithData:(NSString*)unparsedString{
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Could Not Parse, Invalid JSON Response", NSLocalizedDescriptionKey, 
                          unparsedString, kUnparsedJSONStringKey, 
                          nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorJSONParse userInfo:dict];

    return err;

}

+ (NSError*)invalidResponseErrorWithData:(id)invalidData{
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Invalid response from server", NSLocalizedDescriptionKey, 
                          invalidData, kInvalidResponseDataKey, 
                          nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorInvalidResponse userInfo:dict];
    
    return err;
    
}

+ (NSError*)unknownErrorWithDescription:(NSString*)desc{
    
    NSDictionary* dict = nil;
    if(desc)
        dict = [NSDictionary dictionaryWithObjectsAndKeys:
                desc, NSLocalizedDescriptionKey, 
                nil];   
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorUnknown userInfo:dict];
    
    return err;
}

+ (NSError*)userNotAuthenticatedInError{
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"User not logged in", NSLocalizedDescriptionKey, 
                          nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorNotAuthenticated userInfo:dict];
    
    return err;
    
    
}

+ (NSError*)corruptImageResponse:(NSURL*)url data:(NSData*)corruptData{
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Returned Image is corrupt", NSLocalizedDescriptionKey, 
                          corruptData, kCorruptImageResponseDataKey, 
                          url, NSURLErrorKey,
                          nil];
    
    NSError* err = [NSError errorWithDomain:kVimeoErrorDomain code:VimeoErrorCorruptImageResponse userInfo:dict];
    
    return err;
    
    
}
@end
