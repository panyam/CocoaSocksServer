

#import "GCDAsyncSocket.h"
#import "CocoaSocks.h"

////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksAuthMethod

+(int)methodID { return 0; }

/**
 * Handles the authentication negotiation.
 * Override to do method specific authentication.
 * Always call [theConnection negotiationCompleted:YES|NO] to end the auth
 * negotiation with a success or failure.
 */
-(void)startAuthNegotiationForConnection:(SocksConnection *)theConnection 
                              withSocket:(GCDAsyncSocket *)clientSocket
{
    [theConnection negotiationCompleted:YES];
}

/**
 * Called when data has arrived on the socket and when the AuthMethod is the 
 * handler of the data rather than the connection itself.
 */
-(void)connection:(SocksConnection *)theConnection
clientSocketocket:(GCDAsyncSocket *)sock 
      didReadData:(NSData *)data 
          withTag:(long)tag
{
    [theConnection negotiationCompleted:YES];
}

@end

