//
//  FJOffsettableInputStream.m
//  Vimeo
//
//  Created by Corey Floyd on 10/1/10.
//  Copyright 2010 Flying Jalapeño. All rights reserved.
//

#import "FJOffsettableInputStream.h"

@interface FJOffsettableInputStream()

@property (retain, nonatomic) NSInputStream *stream;
@property (nonatomic) BOOL firstRead;

@end

@implementation FJOffsettableInputStream

@synthesize offset;
@synthesize firstRead;
@synthesize stream;


+ (id)inputStreamWithURL:(NSURL *)url{
    
    FJOffsettableInputStream* s = [[[self alloc] init] autorelease];
    s.stream = [NSInputStream inputStreamWithURL:url];
    
    return s;
}

- (void)dealloc
{
	[stream release];
	[super dealloc];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len{
    
    if(firstRead){
                
        NSUInteger bufferSize = 1024;
        
        NSInteger currentByte = 0;
                
        while (currentByte < (NSInteger)(offset - 1)) {
            
            if(offset - currentByte < bufferSize)
                bufferSize = ((offset - 1) - currentByte);
            
            uint8_t buf[bufferSize];
            
            NSInteger currentBufferLength = [stream read:buf maxLength:bufferSize];
            currentByte += currentBufferLength;
        }
        
        firstRead = NO;
    }
    
    return [stream read:buffer maxLength:len];
}


- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len{
    
    return [stream getBuffer:buffer length:len];
    
}

- (BOOL)hasBytesAvailable{
    
    return [stream hasBytesAvailable];
}

- (void)open{
    
    self.firstRead = YES;
    
    [stream open];    
}

- (void)close
{
    [stream close];
}

- (id)delegate
{
    return [stream delegate];
}

- (void)setDelegate:(id)delegate
{
    [stream setDelegate:delegate];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [stream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
    [stream removeFromRunLoop:aRunLoop forMode:mode];
}

- (id)propertyForKey:(NSString *)key
{
    return [stream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return [stream setProperty:property forKey:key];
}

- (NSStreamStatus)streamStatus
{
    return [stream streamStatus];
}

- (NSError *)streamError
{
    return [stream streamError];
}




// If we get asked to perform a method we don't have (probably internal ones),
// we'll just forward the message to our stream

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [stream methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:stream];
}


@end
