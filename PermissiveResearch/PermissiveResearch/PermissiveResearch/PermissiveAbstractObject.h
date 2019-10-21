//
//  PermissiveObject.h
//  PermissiveSearch
//
//  Created by Jerome Morissard on 10/26/13.
//  Copyright (c) 2013 Jerome Morissard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface PermissiveAbstractObject : NSObject

@property (assign, nonatomic) char *flag;
@property (assign, nonatomic) short flagLength;
@property (assign, nonatomic) short score;
@property (readonly, nonatomic) NSString *keyString;

@end
