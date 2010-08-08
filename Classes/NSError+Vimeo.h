
#import <UIKit/UIKit.h>

extern NSString* const kVimeoErrorDomain;

typedef enum  {
    
    VimeoErrorUnknown,
    VimeoErrorNilNetworkResponse,
    VimeoErrorJSONParse,
    VimeoErrorInvalidResponse,
    VimeoErrorNotAuthenticated,
    VimeoErrorCorruptImageResponse
    
} VimeoErrorType;

extern NSString* const kUnparsedJSONStringKey;
extern NSString* const kInvalidResponseDataKey;
extern NSString* const kCorruptImageResponseDataKey;


@interface NSError(Vimeo)

+ (NSError*)errorWithVimeoErrorResponseDictionary:(NSDictionary*)dict;


+ (NSError*)nilNetworkRespnseErrorWithURL:(NSURL*)url;

+ (NSError*)JSONParseErrorWithData:(NSString*)unparsedString;

+ (NSError*)invalidResponseErrorWithData:(id)invalidData;

+ (NSError*)userNotAuthenticatedInError;

+ (NSError*)unknownErrorWithDescription:(NSString*)desc;

+ (NSError*)corruptImageResponse:(NSURL*)url data:(NSData*)corruptData;


@end
