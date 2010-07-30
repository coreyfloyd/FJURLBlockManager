
#import "NetworkDemoViewController.h"
#import "FJBlockURLManager.h"
#import "FJImageCacheManager.h"
#import "FJBlockURLRequest.h"

//#define USE_IMAGE_MANAGER

@implementation NetworkDemoViewController



/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
            
}


- (void)viewWillAppear:(BOOL)animated{
    
    

    

    NSArray* a = [NSArray arrayWithObjects:
                  @"http://farm5.static.flickr.com/4079/4812204972_381e02d013.jpg",
                  @"http://farm5.static.flickr.com/4096/4808757119_21eb97ed7e.jpg",
                  @"http://farm5.static.flickr.com/4101/4809430770_af074e7697.jpg",
                  @"http://farm5.static.flickr.com/4095/4808918950_8fd09bd293.jpg",
                  nil];
    
    
#ifdef USE_IMAGE_MANAGER
    
    FJImageCacheManager* i = [FJImageCacheManager defaultManager];
    
    for(NSString* each in a){
        
        NSURL* url = [NSURL URLWithString:each];
        [i fetchImageAtURL:url 
            respondOnQueue:dispatch_get_main_queue() 
           completionBlock:^(UIImage* image) {
                              
               NSLog(@"image fetched: %@", [image description]);
               
           } 
              failureBlock:^(NSError *error) {
                  
                  NSLog(@"Image fetch error: %@", [error description]);  
                  
              }
         
         requestedByobject:self];
    
    }
    
#else
    
    [[FJBlockURLManager defaultManager] setMaxConcurrentRequests:1];
        
    for(NSString* each in a){
        
            
        NSURL* url = [NSURL URLWithString:each];
        
        FJBlockURLRequest* req = [FJBlockURLRequest requestWithURL:url];
        
        [req setCompletionBlock:^(NSData* result) {
            
            /*
            if([each isEqualToString:@"http://farm5.static.flickr.com/4096/4808757119_21eb97ed7e.jpg"])
                [[FJBlockURLManager defaultManager] suspend];
             */
            
            UIImage* i = [UIImage imageWithData:result];
            
            NSLog(@"image fetched: %@", [i description]);
            
        }]; 
        
        [req setFailureBlock:^(NSError *error) {
            
            NSLog(@"Image fetch error: %@", [error description]);  
            
            
        }];
        
        [req schedule];
        
    }
    
    [[FJBlockURLManager defaultManager] suspend];

    
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:[FJBlockURLManager defaultManager] 
                                   selector:@selector(resume) 
                                   userInfo:nil 
                                    repeats:NO];
    
#endif
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

@end
