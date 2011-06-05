
#import "GCDAsyncSocket.h"
#import "SocksServer.h"
#import "SocksConfig.h"
#import "SocksConstants.h"
#import "SocksConnection.h"
#import "SocksLogging.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int socksLogLevel = SOCKS_LOG_LEVEL_VERBOSE | SOCKS_LOG_FLAG_TRACE;

// Define chunk size used to read in data for responses
// This is how much data will be read from disk into RAM at a time
#if TARGET_OS_IPHONE
  #define READ_CHUNKSIZE  (1024 * 128)
#else
  #define READ_CHUNKSIZE  (1024 * 512)
#endif

@interface SocksConnection (PrivateAPI)
- (void)didReadDataOnClientSocket:(NSData *)data withTag:(long)tag;
- (void)didReadDataOnEndpointSocket:(GCDAsyncSocket *)endpoint withData:(NSData *)data withTag:(long)tag;
- (void)startReadingRequest;
- (void)sendSelectedMethodResponse;
- (void)negotiateConnectionMethod;
- (void)startReadingConnectionRequest;
- (void)readConnectionRequestAddress:(const char *)bytes;
- (void)sendRequestResponse:(unsigned char)reason;
- (void)processConnectionRequest;
- (void)readConnectionData;
@end

// A few timeouts when reading and writing data
#define SOCKS_HEADER_READ_TIMEOUT       30
#define SOCKS_PAYLOAD_READ_TIMEOUT      0
#define SOCKS_HEADER_WRITE_TIMEOUT      30
#define SOCKS_PAYLOAD_WRITE_TIMEOUT     0

// Tags to track the state of the async socket
#define SOCKS_READING_VERSION               10
#define SOCKS_READING_METHOD_LIST           11
#define SOCKS_READING_CONNREQUEST_VERSION   12
#define SOCKS_READING_CONNREQUEST_ADDRESS   13
#define SOCKS_READING_CONN_DATA             14
#define SOCKS_READING_EP_CONN_DATA          15
#define SOCKS_SENDING_METHOD                20

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksConnection

@synthesize version;
@synthesize numAuthMethods;
@synthesize selectedMethod;
@synthesize command;
@synthesize addressType;
@synthesize addressLen;
@synthesize port;

/**
 * This method is automatically called (courtesy of Cocoa) before the first instantiation of this class.
 * We use it to initialize any static variables.
**/
+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
    }
}

- (const unsigned char *)addressBytes
{
    return addressBytes;
}

/**
 * Override to specify which commands are supported.
 */
- (BOOL)isCommandSupported:(char)cmd
{
    return cmd == SOCKS_COMMAND_CONNECT;
    // || cmd == SOCKS_COMMAND_BIND
    // || cmd == SOCKS_COMMAND_UDP_ASSOCIATE;
}

/**
 * Override to specify which address types are supported.
 */
- (BOOL)isAddressTypeSupported:(char)addrType
{
    return addrType == SOCKS_ADDRESS_TYPE_IPV4 ||
    // addrType == SOCKS_ADDRESS_TYPE_IPV6 ||
    addrType == SOCKS_ADDRESS_TYPE_DOMAIN;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init, Dealloc:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sole Constructor.
 * Associates this new connection with the given AsyncSocket.
 * This connection object will become the socket's delegate and take over responsibility for the socket.
**/
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(SocksConfig *)aConfig
{
    if ((self = [super init]))
    {
        SocksLogTrace();

        if (aConfig.queue)
        {
            connectionQueue = aConfig.queue;
            dispatch_retain(connectionQueue);
        }
        else
        {
            connectionQueue = dispatch_queue_create("SocksConnection", NULL);
        }

        // Take over ownership of the socket
        clientSocket = [newSocket retain];
        [clientSocket setDelegate:self delegateQueue:connectionQueue];

        // Store configuration
        config = [aConfig retain];

        host = nil;
        endpointSocket = nil;

        version = 5;
        numAuthMethods = 0;
        selectedMethod = -1;
        command = -1;
        addressType = 0;
        addressLen = -1;
        port = -1;
    }
    return self;
}

/**
 * Standard Deconstructor.
**/
- (void)dealloc
{
    SocksLogTrace();

    dispatch_release(connectionQueue);

    [host release];
    [clientSocket setDelegate:nil delegateQueue:NULL];
    [clientSocket disconnect];
    [clientSocket release];

    // release the endpoint
    [endpointSocket setDelegate:nil delegateQueue:NULL];
    [endpointSocket disconnect];
    [endpointSocket release];

    [config release];
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark Core
///////////////////////////////////////////////////////////////////////////////

/**
 * Starting point for the HTTP connection after it has been fully initialized (including subclasses).
 * This method is called by the HTTP server.
**/
- (void)start
{
    dispatch_async(connectionQueue, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        if (started) return;
        started = YES;

        [self startConnection];

        [pool release];
    });
}

/**
 * This method is called by the Server if it is asked to stop.
 * The server, in turn, invokes stop on each SocksConnection instance.
**/
- (void)stop
{
    dispatch_async(connectionQueue, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // Disconnect the socket.
        // The socketDidDisconnect delegate method will handle everything else.
        [clientSocket disconnect];
        [endpointSocket disconnect];

        [pool release];
    });
}

/**
 * Starting point for the socks connection.
**/
- (void)startConnection
{
    // Override me to do any custom work before the connection starts.
    // Be sure to invoke [super startConnection] when you're done.
    SocksLogTrace();

    [self startReadingRequest];
}

- (void)startReadingRequest
{
    SocksLogTrace();
    [clientSocket readDataToLength:2
                      withTimeout:SOCKS_HEADER_READ_TIMEOUT
                              tag:SOCKS_READING_VERSION];
}

/**
 * This method (after the version number and methods are read), selects an
 * appropritate method to be used for the connection.
 * Override this to change the connection/authentication method.
 */
- (int)selectConnectionMethod
{
    return 0;   // no auth required - YET
}

//////////////////////////////////////////////////////////////////////////////
#pragma mark GCDAsyncSocket delegate
//////////////////////////////////////////////////////////////////////////////

/**
 * Called when connected to a host.
 */
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)epHost port:(UInt16)epPort
{
    NSAssert(endpointSocket == sock, @"Endpoint socket is not same as connected socket");
    SocksLogVerbose(@"Socket: %p, Connected to host: %@ Port: %hu", sock, epHost, epPort);

    // Start reading from the endpoint
    [endpointSocket readDataWithTimeout:-1 tag:SOCKS_READING_EP_CONN_DATA];

    // now start reading from client to forward to the endpoint
    [self readConnectionData];
}

/**
 * Called when any of the sockets disconnected.
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
    if (sock == endpointSocket)
    {
        SocksLogInfo(@"Endpoint Socket: DisConnected");
    }
    else if (sock == clientSocket)
    {
        SocksLogInfo(@"Client Socket: DisConnected");
    }
}

/**
 * This method is called after the socket has successfully read data from
 * the stream.  This is only called after a certain number of bytes have
 * been read (with readDataToLength) or when a certain delimiter has
 * reached (with readDataToData).
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag < 0)
    {
        // -ve tags here for "no action" commands on the async sockets.
        return ;
    }

    if (sock == clientSocket)
    {
        [self didReadDataOnClientSocket:data withTag:tag];
    }
    else
    {
        [self didReadDataOnEndpointSocket:sock withData:data withTag:tag];
    }
}

/////////////////////////////////////////////////////////////////////////////////
#pragma mark Client Socket Data Handling
/////////////////////////////////////////////////////////////////////////////////

/**
 * This method handles all data that is read from clients that are
 * connecting to this proxy with awareness.
 */
- (void)didReadDataOnClientSocket:(NSData *)data withTag:(long)tag
{
    const char *bytes = (const char *)[data bytes];
    switch (tag)
    {
    case SOCKS_READING_VERSION:
        version = bytes[0];
        numAuthMethods = bytes[1];
        // now kick off reading of the methods
        [clientSocket readDataToLength:numAuthMethods
                          withTimeout:SOCKS_HEADER_READ_TIMEOUT
                                  tag:SOCKS_READING_METHOD_LIST];
        break;
    case SOCKS_READING_METHOD_LIST:
        for (int i = 0;i < numAuthMethods;i++)
            authMethods[i] = bytes[i];
        selectedMethod = [self selectConnectionMethod];
        [self sendSelectedMethodResponse];
        break;
    case SOCKS_READING_CONNREQUEST_VERSION:
        version = bytes[0];
        command = bytes[1];
        addressType = bytes[3];
        [self readConnectionRequestAddress:bytes];
        break;
    case SOCKS_READING_CONNREQUEST_ADDRESS:
        [host release]; host = nil;
        if (addressType == SOCKS_ADDRESS_TYPE_IPV4 || addressType == SOCKS_ADDRESS_TYPE_IPV6)
        {
            memcpy(addressBytes + 1, bytes, addressLen - 1);
            port = ((bytes[addressLen - 1] << 8) & 0xff00) |
                   (bytes[addressLen]);
            if (addressType == SOCKS_ADDRESS_TYPE_IPV4)
            {
                host = [[NSString alloc] initWithFormat:@"%d.%d.%d.%d", 
                                                        addressBytes[0], addressBytes[1], 
                                                        addressBytes[2], addressBytes[3]];
            }
            else 
            {
                NSAssert(NO, @"IPV6 Convertion not yet done");
            }
        }
        else
        {
            memcpy(addressBytes, bytes, addressLen);
            port = ((bytes[addressLen] << 8) & 0xff00) |
                   (bytes[addressLen + 1]);
            host = [[NSString alloc] initWithBytes:addressBytes length:addressLen encoding:NSASCIIStringEncoding];
        }

        // send the "response" to the connection method request
        [self sendRequestResponse:0];

        [self processConnectionRequest];
        break;
    case SOCKS_READING_CONN_DATA:
        // finally!  we can now send data we read here onto the endpoint
        [endpointSocket writeData:data withTimeout:-1 tag:0];

        // and read more data 
        [self readConnectionData];
        break;
    }
}

/**
 * Called after selecting an appropriate connection method.
 * This method also notifies the client of the method it can use to 
 * continue with the autentication and encapsulation.
 */
- (void)sendSelectedMethodResponse
{
    char bytes[2] = {version, selectedMethod};
    NSData *data = [NSData dataWithBytes:bytes length:2];
    [clientSocket writeData:data withTimeout:SOCKS_HEADER_WRITE_TIMEOUT tag:SOCKS_SENDING_METHOD];
    [self negotiateConnectionMethod];
}

/**
 * This handles the connection method specific negotiation like
 * authentication etc.
 * Override this (and didReadDataOnClientSocket) to do custom negotiation
 * (by way of injection) and then call [super negotiateConnectionMethod].
 */
- (void)negotiateConnectionMethod
{
    // now read the actual connection request
    [self startReadingConnectionRequest];
}

/**
 * Starts reading the connection request.
 */
- (void)startReadingConnectionRequest
{
    // why are we reading 5 bytes when we ony need 4?
    // because the 5th byte is the start of the dest address and if
    // address type (byte 3) is 3, then the 5th byte is the address
    // length
    [clientSocket readDataToLength:5
                      withTimeout:SOCKS_HEADER_READ_TIMEOUT
                              tag:SOCKS_READING_CONNREQUEST_VERSION];
}

/**
 * This method is called AFTER the command and address type have been read
 * and after the address length has been calculated.
 */
- (void)readConnectionRequestAddress:(const char *)bytes
{
    char addressBytesLeft = 0;
    if (addressType == 1 || addressType == 4)   // IP V4 or V6
    {
        addressLen = 4 * addressType;
        addressBytes[0] = bytes[4];
        addressBytesLeft = addressLen - 1;
    }
    else if (addressType == 3)  // domain name
    {
        addressLen = bytes[4];
        addressBytesLeft = addressLen;
    }

    // see if we have an invalid command or an invalid address type
    if (![self isCommandSupported:command])
    {
        [self sendRequestResponse:SOCKS_RESP_COMMAND_NOT_SUPPORTED];
    }
    if (![self isAddressTypeSupported:command])
    {
        [self sendRequestResponse:SOCKS_RESP_ADDRESS_TYPE_NOT_SUPPORTED];
    }
    else
    {
        // why + 2? because let us read the dest port as well
        [clientSocket readDataToLength:addressBytesLeft + 2
                          withTimeout:SOCKS_HEADER_READ_TIMEOUT
                                  tag:SOCKS_READING_CONNREQUEST_ADDRESS];
    }
}

/**
 * Called after the destination address and port have been read.
 * This also sends the validation response of the connection request to the
 * client by first opening a connection on the remote host.
 */
- (void)processConnectionRequest
{
    if (command == SOCKS_COMMAND_CONNECT)
    {
        // Use the same queue for endpoint connections as well
        // Later on after profiling we could break this up
        endpointSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                    delegateQueue:connectionQueue];

        NSError *error = nil;
        if (![endpointSocket connectToHost:host onPort:port error:&error])
        {
            SocksLogError(@"Error connecting to host...");
        }
        else
        {
            // [self readConnectionData];
        }
    }
}

/**
 * Called to send an "invalid request" response back to the client.
 * This will also put the connection handler back into the "reading
 * request" state.
 */
- (void)sendRequestResponse:(unsigned char)reason
{
    char response[512] = { 0 };
    int responseLength = 6;
    response[0] = version;
    response[1] = reason;
    if (reason == 0)
    {
        response[3] = addressType;
        int start = 4;
        if (addressType == SOCKS_ADDRESS_TYPE_DOMAIN)
        {
            response[start++] = addressType;
            responseLength++;
        }
        memcpy(response + start, addressBytes, addressLen);
        responseLength += addressLen;
    }
    else
    {
        response[3] = SOCKS_ADDRESS_TYPE_IPV4;

        // go back to the "Reading request" state
        [self startReadingConnectionRequest];
    }
    SocksLogVerbose(@"Sending response (Reason: %d) to client, Length: %d", reason, responseLength);
    [clientSocket writeData:[NSData dataWithBytes:response
                                          length:responseLength]
               withTimeout:SOCKS_HEADER_WRITE_TIMEOUT
                       tag:-1];
}

/**
 * Reads more connection data.
 */
- (void)readConnectionData
{
    // and also initiate data reading on the client that we can forward
    // to the endpoint!
    // forward it to all endpoints - is this necessary?  wouldnt there
    // always be only one endpoint (may be not so on a UDP ASSOCIATE or a
    // BIND request).
    [clientSocket readDataWithTimeout:-1 tag:SOCKS_READING_CONN_DATA];
}

/////////////////////////////////////////////////////////////////////////////////
#pragma mark Endpoint Socket Data Handling
/////////////////////////////////////////////////////////////////////////////////

/**
 * This method handles the data read and written by endpoint sockets.
 * Endpoint sockets are the real connection to which this proxy serves the
 * clients with.
 */
- (void)didReadDataOnEndpointSocket:(GCDAsyncSocket *)endpoint withData:(NSData *)data withTag:(long)tag
{
    // then "foward" it directly to the client
    [clientSocket writeData:data withTimeout:-1 tag:0];

    // And read more data so we can forward it
    [endpointSocket readDataWithTimeout:-1 tag:SOCKS_READING_EP_CONN_DATA];
}

@end


