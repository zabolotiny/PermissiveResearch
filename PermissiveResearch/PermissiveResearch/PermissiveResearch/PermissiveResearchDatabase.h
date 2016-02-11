//
//  ScoringDatabase.h
//  PermissiveSearch
//
//  Created by Jerome Morissard on 11/8/13.
//  Copyright (c) 2013 Jerome Morissard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "PermissiveResearch.h"

#define ScoringSegmentLength 3

@interface PermissiveResearchDatabase : NSObject

@property (strong, atomic) NSMutableSet *elements;
@property (weak, nonatomic) id <PermissiveResearchDatasource> datasource;
@property (weak, nonatomic) id <PermissiveResearchDelegate> delegate;

+ (PermissiveResearchDatabase *)sharedDatabase;

- (void)addObject:(id)obj forKey:(NSString *)key;
- (void)addObjects:(NSArray *)obj forKey:(NSString *)key;
- (void)addObjects:(NSArray *)objs forKeys:(NSArray *)keys;
- (void)addObjects:(NSArray *)objs forKeyPaths:(NSArray *)KeyPaths;

- (void)addManagedObject:(NSManagedObject *)obj forKey:(NSString *)key;
- (void)addManagedObjects:(NSArray *)objs forKey:(NSString *)key;
- (void)addManagedObjects:(NSArray *)objs forKeys:(NSArray *)keys;
- (void)addManagedObjects:(NSArray *)objs forKeyPaths:(NSArray *)KeyPaths;

/**
 @brief Add a CoreData object with a custom (key, value) pair.
 
 A substitue to addManagedObject:forKey when the value can be simply inferred from a key, for example if you want to associate values from a to-many relationship.
 
 Eg: a User which has many SocialIdentities, each SocialIdentity having 2 attributes (provider and nickname)
 You can then call:
 
 @code
 [user.identities enumerateObjectsUsingBlock:^(id identity, NSUInteger idx, BOOL *stop) {
 [self addManagedObject:user forKey:identity.provider withValue:identity.nickname]
 }];
 @endcode
 
 @warning It's up to you to provide a suitable key, that is unique from a User perspective.
 
 @param obj The data object that should be returned/indexed
 @param key A custom key that should be unique for a given obj
 @param value The associated value
 */
- (void)addManagedObject:(NSManagedObject *)obj forKey:(NSString *)key withValue:(NSString *)value;

- (NSMutableSet *)objectsForSegment:(NSString *)key;
- (void)searchString:(NSString *)searchedString withOperation:(ScoringOperationType)operationType;

@end
