
#import "SocksAuthMethod.h"
@class PasswordManager;

///////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////

@interface SocksUPAuthMethod : SocksAuthMethod
{
    PasswordManager *passwords;
    NSString *username;
    int usernameLength;
    int passwordLength;
}

@property (nonatomic, retain) PasswordManager *passwords;

+(int)methodID;
-(id)initWithConnection:(SocksConnection *)connection withPasswords:(PasswordManager *)passwords;

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

