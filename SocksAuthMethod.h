
@class SocksConnection;

///////////////////////////////////////////////////////////////////////////
#pragma mark -
///////////////////////////////////////////////////////////////////////////

@interface SocksAuthMethod : NSObject
{
    // The connection this method applies to
    SocksConnection *theConnection;
}

@property (readonly, nonatomic) int methodID;

-(id)initWithConnection:(SocksConnection *)connection;
-(void)dealloc;

@end

