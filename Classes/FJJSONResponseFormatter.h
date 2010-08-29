
#import <Foundation/Foundation.h>
#import "FJBlockURLRequest.h"

@interface FJJSONResponseFormatter : NSObject <FJBlockURLRequestResponseFormatter> {

    id<FJBlockURLRequestResponseFormatter, NSObject> nextFormatter;
}
@property (nonatomic, retain) id<FJBlockURLRequestResponseFormatter, NSObject> nextFormatter;

@end
