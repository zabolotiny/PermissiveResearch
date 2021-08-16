//
//  JMOScoringOperation.m
//  PermissiveSearch
//
//  Created by Jerome Morissard on 10/29/13.
//  Copyright (c) 2013 Jerome Morissard. All rights reserved.
//

#import "PermissiveOperations.h"
#import "PermissiveResearchDatabase.h"
#import "PermissiveAbstractObject.h"
#import "PermissiveAlignementMethods.h"
#import "PermissiveScoringMatrix.h"

#define TICK(XXX) NSDate *XXX = [NSDate date]
#define TOCK(XXX) NSLog(@"TICK|TOCK -> %s: %f", #XXX, -[XXX timeIntervalSinceNow])

@implementation ScoringOperationQueue

+ (ScoringOperationQueue *)mainQueue
{
    static ScoringOperationQueue *mainQueue = nil;
    if (mainQueue == nil)
    {
        mainQueue = [[ScoringOperationQueue alloc] init];
        mainQueue.maxConcurrentOperationCount = 1;
    }
    
    return mainQueue;
}

@end

@implementation ExactScoringOperation

#pragma mark -
#pragma mark - Main operation


- (BOOL)isConcurrent
{
    return NO;
}

- (void)main
{
    @autoreleasepool {
        
        int taille = (int)self.searchedString.length;
        int max = (int)MAX([[[PermissiveResearchDatabase sharedDatabase].elements valueForKeyPath:@"@max.flagLength"] intValue], [self.searchedString length]);
        int **alignementMatrix = allocate2D(max,max);
        
        JMOLog(@"Searching %@ in %d elements", self.searchedString,(int)[PermissiveResearchDatabase sharedDatabase].elements.count);
        [[PermissiveResearchDatabase sharedDatabase].elements enumerateObjectsUsingBlock:^(PermissiveAbstractObject *obj, BOOL *stop) {
            if (self.isCancelled)
                return;
            obj.score = score2Strings(self.searchedString.UTF8String, obj.flag, taille, obj.flagLength,alignementMatrix, 0, [PermissiveScoringMatrix sharedScoringMatrix].structRepresentation);
            
        }];
        
        if (self.isCancelled)
            return;
        
        JMOLog(@"Searching -> Done ");
        
        NSArray *foundElements;
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"score" ascending:NO];

        //Sorting
        if ([PermissiveResearchDatabase sharedDatabase].elements.count > 20) {
            foundElements = [[[PermissiveResearchDatabase sharedDatabase].elements sortedArrayUsingDescriptors:@[sortDescriptor]] subarrayWithRange:NSMakeRange(0, 20)];
        } else {
            foundElements = [[PermissiveResearchDatabase sharedDatabase].elements sortedArrayUsingDescriptors:@[sortDescriptor]];
        }
        
        //LOG MAX
        if (foundElements.count > 0) {
            PermissiveAbstractObject *obj = [foundElements objectAtIndex:0];
            logCalculatedMatrix([self.searchedString UTF8String], obj.flag, (int)taille, obj.flagLength, [PermissiveScoringMatrix sharedScoringMatrix].structRepresentation);
        }
        
        if(self.customCompletionBlock) {
            self.customCompletionBlock(foundElements);
        }
    }
}


@end




@implementation HeuristicScoringOperation

#pragma mark -
#pragma mark - Main operation


- (BOOL)isConcurrent
{
    return NO;
}

- (void)main
{
    @autoreleasepool {
        TICK(HeuristicScoringOperation);
        if (self.searchedString.length < ScoringSegmentLength) {
            if(self.customCompletionBlock) {
                JMOLog(@"Search operation aborded, search operation need more letters");
                self.customCompletionBlock(nil);
            }
            return;
        }
        
        JMOLog(@"Searching %@ in %d elements", self.searchedString,(int)[PermissiveResearchDatabase sharedDatabase].elements.count);
        [[PermissiveResearchDatabase sharedDatabase].elements enumerateObjectsUsingBlock:^(PermissiveObject *obj, BOOL *stop) {
            obj.score = 0;
            if (!obj.refencedObject.isAvailibleForUser && self.shouldBeOnlyAccessible && obj.refencedObject.type == 4) {
                obj.score = -100;
            }
        }];

        const char *searchTermUTF8 = [self.searchedString UTF8String];

        for (int i = 0; i <= self.searchedString.length - ScoringSegmentLength; i++) {
            NSString *segment = [self.searchedString substringWithRange:NSMakeRange(i, ScoringSegmentLength)];
            const char *segmentUTF8 = [segment UTF8String];
            [[[PermissiveResearchDatabase sharedDatabase] objectsForSegment:segment] enumerateObjectsUsingBlock:^(PermissiveAbstractObject *obj, BOOL *stop) {
                // increase score for string starting from first component by 2
                if (i == 0 &&
                    strncasecmp(segmentUTF8, obj.flag, strlen(segmentUTF8)) == 0) {
                    obj.score = obj.score + 2;
                }
                // increase score for string starting from searchquery by 2
                if (i == 0 &&
                    strncasecmp(searchTermUTF8, obj.flag, strlen(searchTermUTF8)) == 0) {
                    obj.score = obj.score + 1;
                }
                obj.score++;
            }];
        }
        
        if (self.isCancelled)
            return;
        
        JMOLog(@"Searching -> Done ");
    
        NSArray *foundElements;
        //Sorting
        NSSortDescriptor *scoreSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"score" ascending:NO];
        NSSortDescriptor *ratingSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"refencedObject.rating" ascending:NO];
        NSSortDescriptor *typeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"refencedObject.type" ascending:NO];
        NSSortDescriptor *flagSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"keyString" ascending:YES];

        //Increase score in order to get exact matches
        [[PermissiveResearchDatabase sharedDatabase].elements enumerateObjectsUsingBlock:^(PermissiveObject*  _Nonnull obj, BOOL * _Nonnull stop) {
            if(strstr(obj.flag, searchTermUTF8) != NULL) {
                obj.score++;
            }
            //Add higher rank to 100% match
            if(strstr(obj.flag, searchTermUTF8) != NULL && strlen(obj.flag) == strlen(searchTermUTF8)) {
                obj.score = obj.score + 100;
            }
        }];
        
        foundElements = [[PermissiveResearchDatabase sharedDatabase].elements sortedArrayUsingDescriptors:@[scoreSortDescriptor, ratingSortDescriptor, flagSortDescriptor]];
        NSInteger maxElementsPerType = 3;
        NSMutableDictionary *addedQtyForEachType = [NSMutableDictionary new];
        
        // get 3 items for each group
        NSMutableArray *resultingArray = [NSMutableArray new];
        
        //LIX exception - while lix is entered then search should be made through lix only
        NSInteger exceptionType = 0;
        if ([self.searchedString.lowercaseString hasPrefix:@"lix"]) {
            exceptionType = 4;
            maxElementsPerType = 9999;
        }
        [foundElements enumerateObjectsUsingBlock:^(PermissiveObject*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.score < 1) {
                return;
            }
            // tag type should have at least 2 scores
            if (obj.refencedObject.type == 4 && obj.score < 2) {
                return;
            }
            // add exception group items
            if (exceptionType == obj.refencedObject.type) {
                [self testDigitsForExceptionCategory:obj andSearchQuery:self.searchedString];
                [resultingArray addObject:obj];
                return;
            }
            // contine if exception is present
            if (exceptionType > 0) {
                return;
            }
            NSString *keyType = @(obj.refencedObject.type).description;
            NSNumber *recordedQty = addedQtyForEachType[keyType];
            if (recordedQty.integerValue >= maxElementsPerType) {
                return;
            }
            [resultingArray addObject:obj];
            NSNumber *newQty = @(recordedQty.integerValue + 1);
            addedQtyForEachType[keyType] = newQty;
        }];
        
        [resultingArray sortUsingDescriptors:@[scoreSortDescriptor, ratingSortDescriptor, flagSortDescriptor]];
        
        //LOG MAX
        if (resultingArray.count > 0) {
            NSUInteger taille = self.searchedString.length;
            PermissiveAbstractObject *obj = [resultingArray objectAtIndex:0];
            logCalculatedMatrix([self.searchedString UTF8String], obj.flag, (int)taille, obj.flagLength, [PermissiveScoringMatrix sharedScoringMatrix].structRepresentation);
            
        }

        if(self.customCompletionBlock) {
            self.customCompletionBlock(resultingArray);
        }
        TOCK(HeuristicScoringOperation);
    }
}

/**
 In order to see in resulting array LIX03 for request lix 3 we need to give more scores for digit matched in string.
 */
- (void)testDigitsForExceptionCategory:(PermissiveObject*) obj
                        andSearchQuery:(NSString*) searchQuery {
    NSString
    *stringDigitsInKey = obj.keyString ? [[obj.keyString componentsSeparatedByCharactersInSet:
                                            [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                                             componentsJoinedByString:@""] : @"";
    NSString *stringDigitsInQuery = searchQuery ? [[searchQuery componentsSeparatedByCharactersInSet:
                                                     [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                                                    componentsJoinedByString:@""] : @"";
    if (stringDigitsInKey.integerValue == stringDigitsInQuery.integerValue &&
        stringDigitsInKey.integerValue > 0) {
        obj.score = obj.score + 3;
    }
}
@end


@implementation HeurexactScoringOperation

#pragma mark -
#pragma mark - Main operation


- (BOOL)isConcurrent
{
    return NO;
}

- (void)main
{
    @autoreleasepool {
        
        if (self.searchedString.length < ScoringSegmentLength) {
            if(self.customCompletionBlock) {
                self.customCompletionBlock(nil);
            }
            return;
        }
        
        JMOLog(@"Searching %@ in %d elements", self.searchedString,(int)[PermissiveResearchDatabase sharedDatabase].elements.count);
        [[PermissiveResearchDatabase sharedDatabase].elements enumerateObjectsUsingBlock:^(PermissiveAbstractObject *obj, BOOL *stop) {
            obj.score = 0;
        }];
        
        for (int i = 0; i < self.searchedString.length - ScoringSegmentLength; i++) {
            NSString *segment = [self.searchedString substringWithRange:NSMakeRange(i, ScoringSegmentLength)];
            [[[PermissiveResearchDatabase sharedDatabase] objectsForSegment:segment] enumerateObjectsUsingBlock:^(PermissiveAbstractObject *obj, BOOL *stop) {
                obj.score++;
            }];
        }
        
        if (self.isCancelled)
            return;
        
        JMOLog(@"Searching -> Done ");
        
        
        JMOLog(@"Start adjusting -> Done ");
        //Sorting
        NSSortDescriptor *scoreSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"score" ascending:NO];
        NSSortDescriptor *ratingSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"refencedObject.rating" ascending:NO];
        NSArray *arrayOfElements = [[PermissiveResearchDatabase sharedDatabase].elements sortedArrayUsingDescriptors:@[scoreSortDescriptor, ratingSortDescriptor]];
        
        int taille = (int)self.searchedString.length;
        int max = (int)MAX([[[PermissiveResearchDatabase sharedDatabase].elements valueForKeyPath:@"@max.flagLength"] intValue], [self.searchedString length]);
        int **alignementMatrix = allocate2D(max,max);
        
        [arrayOfElements enumerateObjectsUsingBlock:^(PermissiveAbstractObject *obj, NSUInteger idx, BOOL *stop) {
            if (self.isCancelled)
                return;
            
            if (idx == 50) {
                *stop = YES;
            }
            
            obj.score = score2Strings(self.searchedString.UTF8String, obj.flag, taille, obj.flagLength,alignementMatrix, 0,[PermissiveScoringMatrix sharedScoringMatrix].structRepresentation);
            
        }];
        
        NSArray *foundElements;
        if (arrayOfElements.count > 20) {
            foundElements = [[arrayOfElements sortedArrayUsingDescriptors:@[scoreSortDescriptor, ratingSortDescriptor]] subarrayWithRange:NSMakeRange(0, 20)];
        } else {
            foundElements = [arrayOfElements sortedArrayUsingDescriptors:@[scoreSortDescriptor, ratingSortDescriptor]];
        }
        
        //LOG MAX
        if (foundElements.count > 0) {
            PermissiveAbstractObject *obj = [foundElements objectAtIndex:0];
            logCalculatedMatrix([self.searchedString UTF8String], obj.flag, (int)taille, obj.flagLength, [PermissiveScoringMatrix sharedScoringMatrix].structRepresentation);
            
        }

        if(self.customCompletionBlock) {
            self.customCompletionBlock(foundElements);
        }
    }
}


@end

