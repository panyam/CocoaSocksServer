#ifndef __SOCKS_CONSTANTS_H__
#define __SOCKS_CONSTANTS_H__

// Socks command type
#define SOCKS_COMMAND_CONNECT       1
#define SOCKS_COMMAND_BIND          2
#define SOCKS_COMMAND_UDP_ASSOCIATE 3

// Socks address types
#define SOCKS_ADDRESS_TYPE_IPV4     1
#define SOCKS_ADDRESS_TYPE_DOMAIN   3
#define SOCKS_ADDRESS_TYPE_IPV6     4

// socks response types
#define SOCKS_RESP_SUCCEEDED                    0
#define SOCKS_RESP_GENERAL_FAILURE              1
#define SOCKS_RESP_NOT_ALLOWED                  2
#define SOCKS_RESP_NETWORK_UNREACHABLE          3
#define SOCKS_RESP_HOST_UNREACABLE              4
#define SOCKS_RESP_CONNECTION_REFUSED           5
#define SOCKS_RESP_TTL_EXPIRED                  6
#define SOCKS_RESP_COMMAND_NOT_SUPPORTED        7
#define SOCKS_RESP_ADDRESS_TYPE_NOT_SUPPORTED   8

#endif

