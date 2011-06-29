
#import "SocksAuthMethod.h"
#import "PasswordManager.h"

///////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////

@interface SocksUPAuthMethod : SocksAuthMethod
{
    PasswordManager *passwords;
}

@property (readonly, nonatomic) int methodID;
@property (nonatomic, retain) PasswordManager *passwords;

-(id)initWithConnection:(SocksConnection *)connection withPasswords:(PasswordManager *)passwords;

@end

