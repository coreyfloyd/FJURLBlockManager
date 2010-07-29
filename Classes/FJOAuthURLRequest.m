
#import "FJOAuthURLRequest.h"
#import "OAConsumer.h"
#import "OAToken.h"
#import "OAHMAC_SHA1SignatureProvider.h"
#import "OASignatureProviding.h"
#import "OARequestParameter.h"
#import "NSMutableURLRequest+Parameters.h"

@interface FJOAuthURLRequest()

@property (nonatomic, retain) OAConsumer *consumer;
@property (nonatomic, retain) OAToken *token;
@property (nonatomic, copy) NSString *realm;
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, retain) id<OASignatureProviding, NSObject> signatureProvider;
@property (nonatomic, copy) NSString *nonce;
@property (nonatomic, copy) NSString *timestamp;

- (void)_prepare;
- (NSString *)_signatureBaseString;
- (void)_generateNonce;
- (void)_generateTimestamp;


@end


@implementation FJOAuthURLRequest

@synthesize consumer;
@synthesize token;
@synthesize realm;
@synthesize signature;
@synthesize signatureProvider;
@synthesize nonce;
@synthesize timestamp;


- (void) dealloc
{
    
    [consumer release];
    consumer = nil;
    [token release];
    token = nil;
    [realm release];
    realm = nil;
    [signature release];
    signature = nil;
    [signatureProvider release];
    signatureProvider = nil;
    [nonce release];
    nonce = nil;
    [timestamp release];
    timestamp = nil;
    [super dealloc];
}


- (id)initWithURL:(NSURL*)url 
         consumer:(OAConsumer*)aConsumer
      accessToken:(OAToken*)aToken
{
    
    self = [super initWithURL:url];
    if (self != nil) {
        
        [self setCachePolicy:NSURLRequestReloadIgnoringCacheData];
                
        self.consumer = aConsumer;
        self.token = aToken;
        self.realm = @"";
        self.signatureProvider = [[[OAHMAC_SHA1SignatureProvider alloc] init] autorelease];
        
        [self _generateTimestamp];
        [self _generateNonce];
        
    }
    return self;
    
}

- (void)scheduleWithNetworkManager:(FJBlockURLManager *)networkManager{
    
    [self _prepare];
    
    [super scheduleWithNetworkManager:networkManager];
}


- (void)_prepare {
    // sign
    //	NSLog(@"Base string is: %@", [self _signatureBaseString]);
    self.signature = [signatureProvider signClearText:[self _signatureBaseString]
                                           withSecret:[NSString stringWithFormat:@"%@&%@", consumer.secret, token.secret ? token.secret : @""]];
    
    // set OAuth headers
	NSMutableArray *chunks = [[NSMutableArray alloc] init];
	[chunks addObject:[NSString stringWithFormat:@"realm=\"%@\"", [realm encodedURLParameterString]]];
	[chunks addObject:[NSString stringWithFormat:@"oauth_consumer_key=\"%@\"", [consumer.key encodedURLParameterString]]];
    
	NSDictionary *tokenParameters = [token parameters];
	for (NSString *k in tokenParameters) {
		[chunks addObject:[NSString stringWithFormat:@"%@=\"%@\"", k, [[tokenParameters objectForKey:k] encodedURLParameterString]]];
	}
    
	[chunks addObject:[NSString stringWithFormat:@"oauth_signature_method=\"%@\"", [[signatureProvider name] encodedURLParameterString]]];
	[chunks addObject:[NSString stringWithFormat:@"oauth_signature=\"%@\"", [signature encodedURLParameterString]]];
	[chunks addObject:[NSString stringWithFormat:@"oauth_timestamp=\"%@\"", timestamp]];
	[chunks addObject:[NSString stringWithFormat:@"oauth_nonce=\"%@\"", nonce]];
	[chunks	addObject:@"oauth_version=\"1.0\""];
	
	NSString *oauthHeader = [NSString stringWithFormat:@"OAuth %@", [chunks componentsJoinedByString:@", "]];
	[chunks release];
    
    [self setValue:oauthHeader forHTTPHeaderField:@"Authorization"];
}



- (void)_generateTimestamp {
    timestamp = [[NSString stringWithFormat:@"%d", time(NULL)] retain];
}

- (void)_generateNonce {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    NSMakeCollectable(theUUID);
    nonce = (NSString *)string;
}


- (NSString *)_signatureBaseString {
    // OAuth Spec, Section 9.1.1 "Normalize Request Parameters"
    // build a sorted array of both request parameters and OAuth header parameters
	NSDictionary *tokenParameters = [token parameters];
	// 6 being the number of OAuth params in the Signature Base String
	NSMutableArray *parameterPairs = [[NSMutableArray alloc] initWithCapacity:(5 + [[self parameters] count] + [tokenParameters count])];
    
    [parameterPairs addObject:[[[OARequestParameter alloc] initWithName:@"oauth_consumer_key" value:consumer.key] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[OARequestParameter alloc] initWithName:@"oauth_signature_method" value:[signatureProvider name]] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[OARequestParameter alloc] initWithName:@"oauth_timestamp" value:timestamp] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[OARequestParameter alloc] initWithName:@"oauth_nonce" value:nonce] URLEncodedNameValuePair]];
    [parameterPairs addObject:[[[OARequestParameter alloc] initWithName:@"oauth_version" value:@"1.0"] URLEncodedNameValuePair]];
	
    
	for(NSString *k in tokenParameters) {
		[parameterPairs addObject:[[OARequestParameter requestParameter:k value:[tokenParameters objectForKey:k]] URLEncodedNameValuePair]];
	}
    
	if (![[self valueForHTTPHeaderField:@"Content-Type"] hasPrefix:@"multipart/form-data"]) {
		for (OARequestParameter *param in [self parameters]) {
			[parameterPairs addObject:[param URLEncodedNameValuePair]];
		}
	}
    
    NSArray *sortedPairs = [parameterPairs sortedArrayUsingSelector:@selector(compare:)];
    NSString *normalizedRequestParameters = [sortedPairs componentsJoinedByString:@"&"];
    
    //	NSLog(@"Normalized: %@", normalizedRequestParameters);
    // OAuth Spec, Section 9.1.2 "Concatenate Request Elements"
    return [NSString stringWithFormat:@"%@&%@&%@",
            [self HTTPMethod],
            [[[self URL] URLStringWithoutQuery] encodedURLParameterString],
            [normalizedRequestParameters encodedURLString]];
}



@end
