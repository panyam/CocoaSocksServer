
#import "SocksAuthMethod.h"
@class PasswordManager;

///////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////

@interface SocksUPAuthMethod : SocksAuthMethod
{
    PasswordManager *passwords;
}

@property (nonatomic, retain) PasswordManager *passwords;

+(int)methodID;
-(id)initWithPasswords:(PasswordManager *)passwords;

/**
 * Handles the authentication negotiation.
 * Override to do method specific authentication.
 * Always call [theConnection negotiationCompleted:YES|NO] to end the auth
 * negotiation with a success or failure.
 */
-(void)startAuthNegotiationForConnection:(SocksConnection *)theConnection 
                              withSocket:(GCDAsyncSocket *)clientSocket;
/**
 * Called when data has arrived on the socket and when the AuthMethod is the 
 * handler of the data rather than the connection itself.
 */
-(void)connection:(SocksConnection *)theConnection
clientSocketocket:(GCDAsyncSocket *)sock 
      didReadData:(NSData *)data 
          withTag:(long)tag;

@end

