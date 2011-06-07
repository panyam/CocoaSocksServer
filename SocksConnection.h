#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class SocksServer;
@class SocksConfig;

#define SocksConnectionDidDieNotification  @"SocksConnectionDidDie"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SocksConnection : NSObject
{
    SocksConfig *config;
    dispatch_queue_t connectionQueue;
    GCDAsyncSocket *clientSocket;

    GCDAsyncSocket *endpointSocket;
    BOOL started;

    /**
     * Version number, num methods, auth methods, command, address that are
     * determined after a connection from a client is acceptd.
     */
    unsigned char version;
    unsigned short numAuthMethods;
    unsigned char authMethods[255];
    short command;
    short selectedMethod;
    unsigned char addressType;
    short addressLen;
    unsigned char addressBytes[256];
    NSString *host;
    int port;
}

@property (nonatomic, readonly) unsigned char version;
@property (nonatomic, readonly) unsigned short numAuthMethods;
@property (nonatomic, readonly) short selectedMethod;
@property (nonatomic, readonly) short command;
@property (nonatomic, readonly) unsigned char addressType;
@property (nonatomic, readonly) short addressLen;
@property (nonatomic, readonly) int port;
@property (nonatomic, readonly) NSData *clientAddress;
@property (nonatomic, readonly) NSData *endpointAddress;
@property (nonatomic, readonly) NSString *clientHost;
@property (nonatomic, readonly) NSString *endpointHost;
@property (nonatomic, readonly) NSUInteger clientPort;
@property (nonatomic, readonly) NSUInteger endpointPort;

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(SocksConfig *)aConfig;
- (void)start;
- (void)stop;
- (void)startConnection;
- (int)selectConnectionMethod;
- (BOOL)isCommandSupported:(char)cmd;
- (BOOL)isAddressTypeSupported:(char)addrType;
- (NSData *)clientAddress;
- (NSString *)clientHost;
- (NSUInteger)clientPort;
- (NSData *)endpointAddress;
- (NSString *)endpointHost;
- (NSUInteger)endpointPort;

@end

