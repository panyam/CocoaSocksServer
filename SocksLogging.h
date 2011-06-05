/**
 * In order to provide fast and flexible logging, this project uses Cocoa Lumberjack.
 * 
 * The Google Code page has a wealth of documentation if you have any questions.
 * http://code.google.com/p/cocoalumberjack/
 * 
 * Here's what you need to know concerning how logging is setup:
 * 
 * There are 4 log levels:
 * - Error
 * - Warning
 * - Info
 * - Verbose
 * 
 * In addition to this, there is a Trace flag that can be enabled.
 * When tracing is enabled, it spits out the methods that are being called.
 * 
 * Please note that tracing is separate from the log levels.
 * For example, one could set the log level to warning, and enable tracing.
 * 
 * All logging is asynchronous, except errors.
 * To use logging within your own custom files, follow the steps below.
 * 
 * Step 1:
 * Import this header in your implementation file:
 * 
 * #import "SocksLogging.h"
 * 
 * Step 2:
 * Define your logging level in your implementation file:
 * 
 * // Log levels: off, error, warn, info, verbose
 * static const int socksLogLevel = SOCKS_LOG_LEVEL_VERBOSE;
 * 
 * If you wish to enable tracing, you could do something like this:
 * 
 * // Debug levels: off, error, warn, info, verbose
 * static const int socksLogLevel = SOCKS_LOG_LEVEL_INFO | SOCKS_LOG_FLAG_TRACE;
 * 
 * Step 3:
 * Replace your NSLog statements with SocksLog statements according to the severity of the message.
 * 
 * NSLog(@"Fatal error, no dohickey found!"); -> SocksLogError(@"Fatal error, no dohickey found!");
 * 
 * SocksLog works exactly the same as NSLog.
 * This means you can pass it multiple variables just like NSLog.
**/

#import "DDLog.h"

// Define logging context for every log message coming from the Socks server.
// The logging context can be extracted from the DDLogMessage from within the logging framework,
// which gives loggers, formatters, and filters the ability to optionally process them differently.

#define SOCKS_LOG_CONTEXT 80

// Configure log levels.
#define SOCKS_LOG_FLAG_ERROR   (1 << 0) // 0...00001
#define SOCKS_LOG_FLAG_WARN    (1 << 1) // 0...00010
#define SOCKS_LOG_FLAG_INFO    (1 << 2) // 0...00100
#define SOCKS_LOG_FLAG_VERBOSE (1 << 3) // 0...01000

#define SOCKS_LOG_LEVEL_OFF     0                                              // 0...00000
#define SOCKS_LOG_LEVEL_ERROR   (SOCKS_LOG_LEVEL_OFF   | SOCKS_LOG_FLAG_ERROR)   // 0...00001
#define SOCKS_LOG_LEVEL_WARN    (SOCKS_LOG_LEVEL_ERROR | SOCKS_LOG_FLAG_WARN)    // 0...00011
#define SOCKS_LOG_LEVEL_INFO    (SOCKS_LOG_LEVEL_WARN  | SOCKS_LOG_FLAG_INFO)    // 0...00111
#define SOCKS_LOG_LEVEL_VERBOSE (SOCKS_LOG_LEVEL_INFO  | SOCKS_LOG_FLAG_VERBOSE) // 0...01111

// Setup fine grained logging.
// The first 4 bits are being used by the standard log levels (0 - 3)
// 
// We're going to add tracing, but NOT as a log level.
// Tracing can be turned on and off independently of log level.

#define SOCKS_LOG_FLAG_TRACE   (1 << 4) // 0...10000

// Setup the usual boolean macros.
#define SOCKS_LOG_ERROR   (socksLogLevel & SOCKS_LOG_FLAG_ERROR)
#define SOCKS_LOG_WARN    (socksLogLevel & SOCKS_LOG_FLAG_WARN)
#define SOCKS_LOG_INFO    (socksLogLevel & SOCKS_LOG_FLAG_INFO)
#define SOCKS_LOG_VERBOSE (socksLogLevel & SOCKS_LOG_FLAG_VERBOSE)
#define SOCKS_LOG_TRACE   (socksLogLevel & SOCKS_LOG_FLAG_TRACE)

// Configure asynchronous logging.
// We follow the default configuration,
// but we reserve a special macro to easily disable asynchronous logging for debugging purposes.
#define SOCKS_LOG_ASYNC_ENABLED   YES

#define SOCKS_LOG_ASYNC_ERROR   ( NO && SOCKS_LOG_ASYNC_ENABLED)
#define SOCKS_LOG_ASYNC_WARN    (YES && SOCKS_LOG_ASYNC_ENABLED)
#define SOCKS_LOG_ASYNC_INFO    (YES && SOCKS_LOG_ASYNC_ENABLED)
#define SOCKS_LOG_ASYNC_VERBOSE (YES && SOCKS_LOG_ASYNC_ENABLED)
#define SOCKS_LOG_ASYNC_TRACE   (YES && SOCKS_LOG_ASYNC_ENABLED)

// Define logging primitives.

#define SocksLogError(frmt, ...)    LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_ERROR,   socksLogLevel, SOCKS_LOG_FLAG_ERROR,  \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogWarn(frmt, ...)     LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_WARN,    socksLogLevel, SOCKS_LOG_FLAG_WARN,   \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogInfo(frmt, ...)     LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_INFO,    socksLogLevel, SOCKS_LOG_FLAG_INFO,    \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogVerbose(frmt, ...)  LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_VERBOSE, socksLogLevel, SOCKS_LOG_FLAG_VERBOSE, \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogTrace()             LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_TRACE,   socksLogLevel, SOCKS_LOG_FLAG_TRACE, \
                                                  SOCKS_LOG_CONTEXT, @"%@[%p]: %@", THIS_FILE, self, THIS_METHOD)

#define SocksLogTrace2(frmt, ...)   LOG_OBJC_MAYBE(SOCKS_LOG_ASYNC_TRACE,   socksLogLevel, SOCKS_LOG_FLAG_TRACE, \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)


#define SocksLogCError(frmt, ...)      LOG_C_MAYBE(SOCKS_LOG_ASYNC_ERROR,   socksLogLevel, SOCKS_LOG_FLAG_ERROR,   \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogCWarn(frmt, ...)       LOG_C_MAYBE(SOCKS_LOG_ASYNC_WARN,    socksLogLevel, SOCKS_LOG_FLAG_WARN,    \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogCInfo(frmt, ...)       LOG_C_MAYBE(SOCKS_LOG_ASYNC_INFO,    socksLogLevel, SOCKS_LOG_FLAG_INFO,    \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogCVerbose(frmt, ...)    LOG_C_MAYBE(SOCKS_LOG_ASYNC_VERBOSE, socksLogLevel, SOCKS_LOG_FLAG_VERBOSE, \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define SocksLogCTrace()               LOG_C_MAYBE(SOCKS_LOG_ASYNC_TRACE,   socksLogLevel, SOCKS_LOG_FLAG_TRACE, \
                                                  SOCKS_LOG_CONTEXT, @"%@[%p]: %@", THIS_FILE, self, __FUNCTION__)

#define SocksLogCTrace2(frmt, ...)     LOG_C_MAYBE(SOCKS_LOG_ASYNC_TRACE,   socksLogLevel, SOCKS_LOG_FLAG_TRACE, \
                                                  SOCKS_LOG_CONTEXT, frmt, ##__VA_ARGS__)

