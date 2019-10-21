//
//  PermissiveObject.h
//  PermissiveResearch
//
//  Created by Jerome Morissard on 5/15/14.
//  Copyright (c) 2014 Jerome Morissard. All rights reserved.
//

#import "PermissiveAbstractObject.h"
@protocol PermissiveRelativeObjectProtocol <NSObject>

@property (nonatomic, assign) double rating;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) BOOL isAvailibleForUser;


@end

@interface PermissiveObject : PermissiveAbstractObject

@property (strong, nonatomic) id<PermissiveRelativeObjectProtocol> refencedObject;

@end
