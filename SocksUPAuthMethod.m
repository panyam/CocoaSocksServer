

#import "SocksUPAuthMethod.h"
#import "SocksConnection.h"
#import "SocksLogging.h"
#import "PasswordManager.h"

////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////////////////////

#define SOCKS_READ_UNAME_LEN            10
#define SOCKS_READ_UNAME_AND_PASSWD_LEN 11
#define SOCKS_READ_PASSWORD             12
#define SOCKS_READ_TIMEOUT              30

@implementation SocksUPAuthMethod

@synthesize passwords;

+(int)methodID { return 1; }

-(id)initWithConnection:(SocksConnection *)connection withPasswords:(PasswordManager *)passwords_
{
    if ((self = [self initWithConnection:connection]))
    {
        username = nil;
        passwords = [passwords_ retain];
    }
    return self;
}

-(void)dealloc
{
    [username release];
    [passwords release];
    [super dealloc];
}

/**
 * Handles the authentication negotiation.
 * Override to do method specific authentication.
 * Always call [theConnection negotiationCompleted:YES|NO] to end the auth
 * negotiation with a success or failure.
 */
-(void)startAuthNegotiationWithClient:(GCDAsyncSocket *)clientSocket;
{
    SocksLogTrace();
    // read version and uname length
    [clientSocket readDataToLength:2
                      withTimeout:SOCKS_READ_TIMEOUT
                              tag:SOCKS_READ_UNAME_LEN];
}

/**
 * Called when data has arrived on the socket and when the AuthMethod is the 
 * handler of the data rather than the connection itself.
 */
-(void)clientSocket:(GCDAsyncSocket *)sock 
        didReadData:(NSData *)data 
            withTag:(long)tag
{
    const char *bytes = (const char *)([data bytes]);
    if (tag == SOCKS_READ_UNAME_LEN)
    {
        // int version = bytes[0] & 0xff;
        usernameLength = bytes[1] & 0xff;
        // read username + password length
        [sock readDataToLength:usernameLength + 1
                   withTimeout:SOCKS_READ_TIMEOUT
                           tag:SOCKS_READ_UNAME_AND_PASSWD_LEN];
    }
    else if (tag == SOCKS_READ_UNAME_AND_PASSWD_LEN)
    {
        username = [[NSString alloc] initWithBytes:bytes 
                                            length:usernameLength 
                                          encoding:NSASCIIStringEncoding];
        passwordLength = bytes[usernameLength] & 0xff;
        [sock readDataToLength:passwordLength
                   withTimeout:SOCKS_READ_TIMEOUT
                           tag:SOCKS_READ_PASSWORD];
    }
    else if (tag == SOCKS_READ_PASSWORD)
    {
        NSString *password = [[[NSString alloc] initWithBytes:bytes 
                                            length:passwordLength 
                                                     encoding:NSASCIIStringEncoding] autorelease];
        [username release]; username = nil;
        if ([[passwords getPasswordForUser:username] isEqualToString:password])
        {
            SocksLogVerbose(@"Passwords matched for username: %@", username);
            [theConnection negotiationCompleted:YES]; 
        }
        else
        {
            SocksLogVerbose(@"Passwords did not match for username: %@", username);
            [theConnection negotiationCompleted:NO]; 
        }
    }
}

@end

