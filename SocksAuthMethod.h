
#import "GCDAsyncSocket.h"
@class SocksConnection;

///////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////

@interface SocksAuthMethod : NSObject
{
    SocksConnection *theConnection;
}

+(int)methodID;
-(id)initWithConnection:(SocksConnection *)connection;

/**
 * Handles the authentication negotiation.
 * Override to do method specific authentication.
 * Always call [theConnection negotiationCompleted:YES|NO] to end the auth
 * negotiation with a success or failure.
 */
-(void)startAuthNegotiationWithClient:(GCDAsyncSocket *)clientSocket;

/**
 * Called when data has arrived on the socket and when the AuthMethod is the 
 * handler of the data rather than the connection itself.
 */
-(void)clientSocket:(GCDAsyncSocket *)sock 
        didReadData:(NSData *)data 
            withTag:(long)tag;

@end

