//
//  FJOffsettableInputStream.h
//  Vimeo
//
//  Created by Corey Floyd on 10/1/10.
//  Copyright 2010 Flying Jalapeño. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FJOffsettableInputStream : NSObject {
    NSInteger offset;
}
@property (nonatomic) NSInteger offset; //set the first byte you want to read from the file stream

+ (id)inputStreamWithURL:(NSURL *)url;

@end
