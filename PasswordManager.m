//
//  PasswordManager.m
//  MySocks
//
//  Created by Sri Panyam on 29/06/11.
//  Copyright 2011 Sri Panyam. All rights reserved.
//

#import "PasswordManager.h"

@implementation PasswordManager

- (id)init
{
    self = [super init];
    if (self) {
        passwords = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [passwords release];
    [super dealloc];
}

/**
 * Adds a new user.  Returns FALSE if the user already exists.
 */
-(BOOL)addUser:(NSString *)username withPassword:(NSString *)password overrideExisting:(BOOL)override
{
    return NO;
}

/**
 * Adds a new user.  Returns FALSE if the user already exists.
 */
-(BOOL)addUser:(NSString *)username withPassword:(NSString *)password
{
    return [self addUser:username withPassword:password overrideExisting:NO];
}

-(void) removeUser:(NSString *)username
{
}

-(void) getPasswordForUser:(NSString *)username
{
}

-(void) setPasswordForUser:(NSString *)username withPassword:(NSString *)password
{
}

@end
