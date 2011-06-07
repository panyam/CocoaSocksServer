#import "SocksServer.h"
#import "SocksConfig.h"
#import "SocksConnection.h"
#import "GCDAsyncSocket.h"
#import "SocksLogging.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int socksLogLevel = SOCKS_LOG_LEVEL_INFO; // | SOCKS_LOG_FLAG_TRACE;

@interface SocksServer (PrivateAPI)

- (void)unpublishBonjour;
- (void)publishBonjour;

+ (void)startBonjourThreadIfNeeded;
+ (void)performBonjourBlock:(dispatch_block_t)block waitUntilDone:(BOOL)waitUntilDone;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SocksServer

/**
 * Standard Constructor.
 * Instantiates a server, but does not start it.
**/
- (id)init
{
    if ((self = [super init]))
    {
        SocksLogTrace();

        // Initialize underlying dispatch queue and GCD based tcp socket
        serverQueue = dispatch_queue_create("SocksServer", NULL);
        asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serverQueue];

        // Use default connection class of SocksConnection
        connectionQueue = dispatch_queue_create("SocksConnection", NULL);
        connectionClass = [SocksConnection self];

        // By default bind on all available interfaces, en1, wifi etc
        interface = nil;

        // Use a default port of 0
        // This will allow the kernel to automatically pick an open port for us
        port = 0;

        // Configure default values for bonjour service

        // Bonjour domain. Use the local domain by default
        domain = @"local.";

        // If using an empty string ("") for the service name when registering,
        // the system will automatically use the "Computer Name".
        // Passing in an empty string will also handle name conflicts
        // by automatically appending a digit to the end of the name.
        name = @"";

        // Initialize arrays to hold all connections
        connections = [[NSMutableArray alloc] init];

        connectionsLock = [[NSLock alloc] init];

        // Register for notifications of closed connections
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionDidDie:)
                                                     name:SocksConnectionDidDieNotification
                                                   object:nil];

        isRunning = NO;
    }
    return self;
}

/**
 * Standard Deconstructor.
 * Stops the server, and clients, and releases any resources connected with this instance.
**/
- (void)dealloc
{
    SocksLogTrace();

    // Remove notification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Stop the server if it's running
    [self stop];

    // Release all instance variables

    dispatch_release(serverQueue);
    dispatch_release(connectionQueue);

    [asyncSocket setDelegate:nil delegateQueue:NULL];
    [asyncSocket release];

    [interface release];

    [netService release];
    [domain release];
    [name release];
    [type release];
    [txtRecordDictionary release];

    [connections release];
    [connectionsLock release];

    [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The connection class is the class that will be used to handle connections.
 * That is, when a new connection is created, an instance of this class will be intialized.
 * The default connection class is SocksConnection.
 * If you use a different connection class, it is assumed that the class extends SocksConnection
**/
- (Class)connectionClass
{
    __block Class result;

    dispatch_sync(serverQueue, ^{
        result = connectionClass;
    });

    return result;
}

- (void)setConnectionClass:(Class)value
{
    SocksLogTrace();

    dispatch_async(serverQueue, ^{
        connectionClass = value;
    });
}

/**
 * What interface to bind the listening socket to.
**/
- (NSString *)interface
{
    __block NSString *result;

    dispatch_sync(serverQueue, ^{
        result = [interface retain];
    });

    return [result autorelease];
}

- (void)setInterface:(NSString *)value
{
    NSString *valueCopy = [value copy];

    dispatch_async(serverQueue, ^{
        [interface release];
        interface = [valueCopy retain];
    });

    [valueCopy release];
}

/**
 * The port to listen for connections on.
 * By default this port is initially set to zero, which allows the kernel to pick an available port for us.
 * After the server has started, the port being used may be obtained by this method.
**/
- (UInt16)port
{
    __block UInt16 result;

    dispatch_sync(serverQueue, ^{
        result = port;
    });

    return result;
}

- (UInt16)listeningPort
{
    __block UInt16 result;

    dispatch_sync(serverQueue, ^{
        if (isRunning)
            result = [asyncSocket localPort];
        else
            result = 0;
    });

    return result;
}

- (void)setPort:(UInt16)value
{
    SocksLogTrace();

    dispatch_async(serverQueue, ^{
        port = value;
    });
}

/**
 * Domain on which to broadcast this service via Bonjour.
 * The default domain is @"local".
**/
- (NSString *)domain
{
    __block NSString *result;

    dispatch_sync(serverQueue, ^{
        result = [domain retain];
    });

    return [domain autorelease];
}

- (void)setDomain:(NSString *)value
{
    SocksLogTrace();

    NSString *valueCopy = [value copy];

    dispatch_async(serverQueue, ^{
        [domain release];
        domain = [valueCopy retain];
    });

    [valueCopy release];
}

/**
 * The name to use for this service via Bonjour.
 * The default name is an empty string,
 * which should result in the published name being the host name of the computer.
**/
- (NSString *)name
{
    __block NSString *result;

    dispatch_sync(serverQueue, ^{
        result = [name retain];
    });

    return [name autorelease];
}

- (NSString *)publishedName
{
    __block NSString *result;

    dispatch_sync(serverQueue, ^{

        if (netService == nil)
        {
            result = nil;
        }
        else
        {

            dispatch_block_t bonjourBlock = ^{
                result = [[netService name] copy];
            };

            [[self class] performBonjourBlock:bonjourBlock waitUntilDone:YES];
        }
    });

    return [result autorelease];
}

- (void)setName:(NSString *)value
{
    NSString *valueCopy = [value copy];

    dispatch_async(serverQueue, ^{
        [name release];
        name = [valueCopy retain];
    });

    [valueCopy release];
}

/**
 * The type of service to publish via Bonjour.
 * No type is set by default, and one must be set in order for the service to be published.
**/
- (NSString *)type
{
    __block NSString *result;

    dispatch_sync(serverQueue, ^{
        result = [type retain];
    });

    return [result autorelease];
}

- (void)setType:(NSString *)value
{
    NSString *valueCopy = [value copy];

    dispatch_async(serverQueue, ^{
        [type release];
        type = [valueCopy retain];
    });

    [valueCopy release];
}

/**
 * The extra data to use for this service via Bonjour.
**/
- (NSDictionary *)TXTRecordDictionary
{
    __block NSDictionary *result;

    dispatch_sync(serverQueue, ^{
        result = [txtRecordDictionary retain];
    });

    return [result autorelease];
}
- (void)setTXTRecordDictionary:(NSDictionary *)value
{
    SocksLogTrace();

    NSDictionary *valueCopy = [value copy];

    dispatch_async(serverQueue, ^{

        [txtRecordDictionary release];
        txtRecordDictionary = [valueCopy retain];

        // Update the txtRecord of the netService if it has already been published
        if (netService)
        {
            NSNetService *theNetService = netService;
            NSData *txtRecordData = nil;
            if (txtRecordDictionary)
                txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];

            dispatch_block_t bonjourBlock = ^{
                [theNetService setTXTRecordData:txtRecordData];
            };

            [[self class] performBonjourBlock:bonjourBlock waitUntilDone:NO];
        }
    });

    [valueCopy release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Control
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)start:(NSError **)errPtr
{
    SocksLogTrace();

    __block BOOL success = YES;
    __block NSError *err = nil;

    dispatch_sync(serverQueue, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        success = [asyncSocket acceptOnInterface:interface port:port error:&err];
        if (success)
        {
            SocksLogInfo(@"%@: Started Socks server on port %hu", THIS_FILE, [asyncSocket localPort]);

            isRunning = YES;
            [self publishBonjour];
        }
        else
        {
            SocksLogError(@"%@: Failed to start Socks Server: %@", THIS_FILE, err);
            [err retain];
        }

        [pool release];
    });

    if (errPtr)
        *errPtr = [err autorelease];
    else
        [err release];

    return success;
}

- (BOOL)stop
{
    SocksLogTrace();

    dispatch_sync(serverQueue, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // First stop publishing the service via bonjour
        [self unpublishBonjour];

        // Stop listening / accepting incoming connections
        [asyncSocket disconnect];
        isRunning = NO;

        // Now stop all connections the server owns
        [connectionsLock lock];
        for (SocksConnection *connection in connections)
        {
            [connection stop];
        }
        [connections removeAllObjects];
        [connectionsLock unlock];

        [pool release];
    });

    return YES;
}

- (BOOL)isRunning
{
    __block BOOL result;

    dispatch_sync(serverQueue, ^{
        result = isRunning;
    });

    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of connections that are currently connected to the server.
**/
- (NSUInteger)numberOfConnections
{
    NSUInteger result = 0;

    [connectionsLock lock];
    result = [connections count];
    [connectionsLock unlock];

    return result;
}

/**
 * Returns a summary/detail about the connection at a given index.
 */
- (void)connectionAtIndex:(NSUInteger)index
            sourceAddress:(NSString **)sourceAddress
               sourcePort:(NSUInteger)sourcePort
              destAddress:(NSString **)destAddress
                 destPort:(NSUInteger)destPort
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Incoming Connections
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SocksConfig *)config
{
    // Override me if you want to provide a custom config to the new connection.
    // 
    // Generally this involves overriding the SocksConfig class to include any custom settings,
    // and then having this method return an instance of 'MySocksConfig'.
    return [[[SocksConfig alloc] initWithServer:self queue:connectionQueue] autorelease];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    SocksConnection *newConnection = (SocksConnection *)[[connectionClass alloc] initWithAsyncSocket:newSocket
                                                                                     configuration:[self config]];
    [connectionsLock lock];
    [connections addObject:newConnection];
    [connectionsLock unlock];

    [newConnection start];
    [newConnection release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)publishBonjour
{
    SocksLogTrace();

    NSAssert(dispatch_get_current_queue() == serverQueue, @"Invalid queue");

    if (type)
    {
        netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:[asyncSocket localPort]];
        [netService setDelegate:self];

        NSNetService *theNetService = netService;
        NSData *txtRecordData = nil;
        if (txtRecordDictionary)
            txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];

        dispatch_block_t bonjourBlock = ^{

            [theNetService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [theNetService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [theNetService publish];

            // Do not set the txtRecordDictionary prior to publishing!!!
            // This will cause the OS to crash!!!
            if (txtRecordData)
            {
                [theNetService setTXTRecordData:txtRecordData];
            }
        };

        [[self class] startBonjourThreadIfNeeded];
        [[self class] performBonjourBlock:bonjourBlock waitUntilDone:NO];
    }
}

- (void)unpublishBonjour
{
    SocksLogTrace();

    NSAssert(dispatch_get_current_queue() == serverQueue, @"Invalid queue");

    if (netService)
    {
        NSNetService *theNetService = netService;

        dispatch_block_t bonjourBlock = ^{

            [theNetService stop];
            [theNetService release];
        };

        [[self class] performBonjourBlock:bonjourBlock waitUntilDone:NO];

        netService = nil;
    }
}

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
**/
- (void)republishBonjour
{
    SocksLogTrace();

    dispatch_async(serverQueue, ^{

        [self unpublishBonjour];
        [self publishBonjour];
    });
}

/**
 * Called when our bonjour service has been successfully published.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netServiceDidPublish:(NSNetService *)ns
{
    // Override me to do something here...
    // 
    // Note: This method is invoked on our bonjour thread.

    SocksLogInfo(@"Bonjour Service Published: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
}

/**
 * Called if our bonjour service failed to publish itself.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
    // Override me to do something here...
    // 
    // Note: This method in invoked on our bonjour thread.

    SocksLogWarn(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@",
                                             [ns domain], [ns type], [ns name], errorDict);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is automatically called when a notification of type SocksConnectionDidDieNotification is posted.
 * It allows us to remove the connection from our array.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
    // Note: This method is called on the connection queue that posted the notification

    [connectionsLock lock];

    SocksLogTrace();
    [connections removeObject:[notification object]];

    [connectionsLock unlock];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Thread
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * NSNetService is runloop based, so it requires a thread with a runloop.
 * This gives us two options:
 * 
 * - Use the main thread
 * - Setup our own dedicated thread
 * 
 * Since we have various blocks of code that need to synchronously access the netservice objects,
 * using the main thread becomes troublesome and a potential for deadlock.
**/

static NSThread *bonjourThread;

+ (void)startBonjourThreadIfNeeded
{
    SocksLogTrace();

    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{

        SocksLogVerbose(@"%@: Starting bonjour thread...", THIS_FILE);

        bonjourThread = [[NSThread alloc] initWithTarget:self
                                                selector:@selector(bonjourThread)
                                                  object:nil];
        [bonjourThread start];
    });
}

+ (void)bonjourThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    SocksLogVerbose(@"%@: BonjourThread: Started", THIS_FILE);

    // We can't run the run loop unless it has an associated input source or a timer.
    // So we'll just create a timer that will never fire - unless the server runs for 10,000 years.

    [NSTimer scheduledTimerWithTimeInterval:DBL_MAX target:self selector:@selector(ignore:) userInfo:nil repeats:YES];

    [[NSRunLoop currentRunLoop] run];

    SocksLogVerbose(@"%@: BonjourThread: Aborted", THIS_FILE);

    [pool release];
}

+ (void)performBonjourBlock:(dispatch_block_t)block
{
    SocksLogTrace();

    NSAssert([NSThread currentThread] == bonjourThread, @"Executed on incorrect thread");

    block();
}

+ (void)performBonjourBlock:(dispatch_block_t)block waitUntilDone:(BOOL)waitUntilDone
{
    SocksLogTrace();

    dispatch_block_t bonjourBlock = Block_copy(block);

    [self performSelector:@selector(performBonjourBlock:)
                 onThread:bonjourThread
               withObject:bonjourBlock
            waitUntilDone:waitUntilDone];

    Block_release(bonjourBlock);
}

@end

