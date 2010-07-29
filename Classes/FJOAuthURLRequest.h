
//Based on OAMutableURLRequest from jdg/oauthconsumer

#import <Foundation/Foundation.h>
#import "FJBlockURLRequest.h"

@class OAConsumer;
@class OAToken;


@interface FJOAuthURLRequest : FJBlockURLRequest {

}

//only use this initializer
- (id)initWithURL:(NSURL*)url 
         consumer:(OAConsumer*)aConsumer
      accessToken:(OAToken*)aToken;

@end
