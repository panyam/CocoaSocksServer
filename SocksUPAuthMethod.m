

#import "SocksUPAuthMethod.h"
#import "SocksLogging.h"

////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
/////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksUPAuthMethod

@synthesize passwords;

-(id)initWithConnection:(SocksConnection *)connection
{
    return [self initWithConnection:connection withPasswords:nil];
}

-(id)initWithConnection:(SocksConnection *)connection withPasswords:(PasswordManager *)passwords_
{
    if ((self = [super initWithConnection:connection]))
    {
        passwords = [passwords_ retain];
    }
    return self;
}

-(void)dealloc
{
    [passwords release];
    [super dealloc];
}

-(int)methodID
{
    return 1;
}

@end

