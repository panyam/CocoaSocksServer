//
//  PasswordManager.h
//  MySocks
//
//  Created by Sri Panyam on 29/06/11.
//  Copyright 2011 Sri Panyam. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PasswordManager : NSObject {
    NSMutableDictionary *passwords;
}

-(BOOL)addUser:(NSString *)username withPassword:(NSString *)password overrideExisting:(BOOL)override;
-(BOOL)addUser:(NSString *)username withPassword:(NSString *)password;
-(void)removeUser:(NSString *)username;
-(void)getPasswordForUser:(NSString *)username;
-(void)setPasswordForUser:(NSString *)username withPassword:(NSString *)password;

@end
