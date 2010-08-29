
#import <Foundation/Foundation.h>
#import "FJBlockURLRequest.h"

@class OAConsumer;
@class OAToken;

@interface FJOAuthHeaderProvider : NSObject <FJBlockURLRequestHeaderProvider> {

}

+ (FJOAuthHeaderProvider*)authorizationHeaderProviderWithConsumer:(OAConsumer*)aConsumer;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;                                                


+ (FJOAuthHeaderProvider*)headerproviderWithConsumer:(OAConsumer*)aConsumer 
                                         accessToken:(OAToken*)aToken;

- (id)initWithConsumer:(OAConsumer*)aConsumer 
           accessToken:(OAToken*)aToken;

@property (nonatomic, retain) OAToken *token; //you may need to set this multiple times in certain applications

@end


//TODO: seperate authentication header and request header into 2 seperate things for better error cheking (you can check that a token is null)
