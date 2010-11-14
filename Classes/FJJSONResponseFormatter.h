
#import <Foundation/Foundation.h>
#import "FJBlockURLRequest.h"

//uses JSONKit to format responses
@interface FJJSONResponseFormatter : NSObject <FJBlockURLRequestResponseFormatter> {

    id<FJBlockURLRequestResponseFormatter, NSObject> nextFormatter;
}

@end
