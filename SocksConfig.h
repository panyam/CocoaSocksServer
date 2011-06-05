#import <Foundation/Foundation.h>
@class SocksServer;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SocksConfig : NSObject
{
	SocksServer *server;
	dispatch_queue_t queue;
}

- (id)initWithServer:(SocksServer *)server ;
- (id)initWithServer:(SocksServer *)server queue:(dispatch_queue_t)q;

@property (nonatomic, readonly) SocksServer *server;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

