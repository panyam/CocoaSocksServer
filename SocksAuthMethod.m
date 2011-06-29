

#import "GCDAsyncSocket.h"
#import "SocksConfig.h"
#import "SocksConstants.h"
#import "SocksConnection.h"
#import "SocksAuthMethod.h"
#import "SocksLogging.h"

////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksAuthMethod

-(id)initWithConnection:(SocksConnection *)connection
{
    if ((self = [super init]))
    {
        theConnection = [connection retain];
    }
    return self;
}

-(void)dealloc
{
    [theConnection release];
    [super dealloc];
}

-(int)methodID
{
    return 0;
}

@end

