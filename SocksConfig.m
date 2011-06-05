
#import "SocksServer.h"
#import "SocksConfig.h"
#import "SocksLogging.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int socksLogLevel = SOCKS_LOG_LEVEL_WARN; // | SOCKS_LOG_FLAG_TRACE;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksConfig

@synthesize server;
@synthesize queue;

- (id)initWithServer:(SocksServer *)aServer 
{
    if ((self = [super init]))
    {
        server = [aServer retain];
    }
    return self;
}

- (id)initWithServer:(SocksServer *)aServer queue:(dispatch_queue_t)q
{
    if ((self = [super init]))
    {
        server = [aServer retain];

        if (q)
        {
            dispatch_retain(q);
            queue = q;
        }
    }
    return self;
}

- (void)dealloc
{
    [server release];

    if (queue)
        dispatch_release(queue);

    [super dealloc];
}

@end
