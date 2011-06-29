

#import "GCDAsyncSocket.h"
#import "CocoaSocks.h"

////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksAuthMethod

+(int)methodID { return 0; }

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

/**
 * Handles the authentication negotiation.
 * Override to do method specific authentication.
 * Always call [theConnection negotiationCompleted:YES|NO] to end the auth
 * negotiation with a success or failure.
 */
-(void)startAuthNegotiationWithClient:(GCDAsyncSocket *)clientSocket
{
    [theConnection negotiationCompleted:YES];
}

/**
 * Called when data has arrived on the socket and when the AuthMethod is the 
 * handler of the data rather than the connection itself.
 */
-(void)clientSocket:(GCDAsyncSocket *)sock 
        didReadData:(NSData *)data 
            withTag:(long)tag
{
    [theConnection negotiationCompleted:YES];
}

@end

