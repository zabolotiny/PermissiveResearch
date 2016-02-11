## My other works

[http://leverdeterre.github.io] (http://leverdeterre.github.io)


[![Twitter](https://img.shields.io/badge/contact-@leverdeterre-green.svg)](http://twitter.com/leverdeterre)
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/leverdeterre/PermissiveResearch/blob/master/LICENCE)
[![Cocoapods](http://img.shields.io/cocoapods/v/PermissiveResearch.svg)](https://github.com/leverdeterre/PermissiveResearch)

PermissiveResearch
==================

A performant iOS search engine that supports fuzzy matching (or approximate string matching), ie the ability to return matches that may be less than 100% accurate; it helps make searches tolerant to typographic errors / approximations.

It replaces CoreData fetch requests or NSArray filters with predicate.

![Image](demo.png)

PermissiveResearch is a alternative to simplify the search step.
Advantages :
- Fast (see performances below),
- Easy to implement with any existing data and without modifying any existing data model,
- Manages CoreData context/threads CoreData for you,
- Handle huge datasets,
- Search algorithm can be customized easily,
- 3 algorithms already implemented.

### Performances (on iPhone4, searching in 4 properties amongst 5.000 objects)

|  Type of search  | time (ms) | data structure |
| ------------- |:-------------:| -------------|
|  Exact search  | 200 | Using predicates      |
|  Exact search  | 2800 | Using PermissiveResearch (ExactScoringOperation*)   |
|  Exact search  | 100 | Using PermissiveResearch (HeuristicScoringOperation*)  |
|  Exact search  | 700 | Using PermissiveResearch (HeurexactScoringOperation*)  |
|  Tolerated search  | impossible.. | Using predicates  |
|  Tolerated search  | 2800 | Using PermissiveResearch (ExactScoringOperation*)   |
|  Tolerated search  | 100 | Using PermissiveResearch (HeuristicScoringOperation*)  |
|  Tolerated search  | 700 | Using PermissiveResearch (HeurexactScoringOperation*)  |

* ExactScoringOperation : Make a complex and total analysis,
* HeuristicScoringOperation : Scan using fragments (default size 3),
* HeurexactScoringOperation : Scan using fragments (default size 3), then make a complex and total analysis of the best pre-selected objects.

### Algorithms
It's a custom implementation of the [Smith-Waterman algorithm][1].
The purpose of the algorithm is to obtain the optimum local alignment.
A similarity matrix is use to tolerate errors.
[1]: http://en.wikipedia.org/wiki/Smith–Waterman_algorithm

### Shared instance
```objective-c
[[PermissiveResearchDatabase sharedDatabase] setDatasource:self];
```

### Datasource methods to fill your search database
```objective-c
-(void)rebuildDatabase
```

```objective-c
- (void)addObject:(id)obj forKey:(NSString *)key;
- (void)addObjects:(NSArray *)obj forKey:(NSString *)key;
- (void)addObjects:(NSArray *)objs forKeys:(NSArray *)keys;
- (void)addObjects:(NSArray *)objs forKeyPaths:(NSArray *)KeyPaths;

- (void)addManagedObject:(NSManagedObject *)obj forKey:(NSString *)key;
- (void)addManagedObjects:(NSArray *)objs forKey:(NSString *)key;
- (void)addManagedObjects:(NSArray *)objs forKeys:(NSArray *)keys;
- (void)addManagedObjects:(NSArray *)objs forKeyPaths:(NSArray *)KeyPaths;

- (void)addManagedObject:(NSManagedObject *)obj forKey:(NSString *)key withValue:(NSString *)value;
```

Example :

```objective-c
///PermissiveResearchDatabase datasource
-(void)rebuildDatabase
{
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"data5000"
                                                         ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data
                                              options:kNilOptions
                                                error:&error];

    [[PermissiveResearchDatabase sharedDatabase] addObjects:json forKeyPaths:@[@"name",@"gender",@"company",@"email"]];
    self.searchedList = json;
}
```

### Datasource method to customize scoring methods
```objective-c
-(NSInteger)customCostForEvent:(ScoringEvent)event
```

Example (default values) :
```objective-c
-(NSInteger)customCostForEvent:(ScoringEvent)event
{
    switch (event) {
        case ScoringEventPerfectMatch:
            return 2;
            break;

        case ScoringEventNotPerfectMatchKeyboardAnalyseHelp:
            return 1;
            break;

        case ScoringEventNotPerfectBecauseOfAccents:
            return 2;
            break;

        case ScoringEventLetterAddition:
            return -1;
            break;

        default:
            break;
    }

    return NSNotFound;
}
```


### Easy search operation using PermissiveResearch delegate
```objective-

[[PermissiveResearchDatabase sharedDatabase] setDelegate:self];
[[PermissiveResearchDatabase sharedDatabase] searchString:searchedString withOperation:ScoringOperationTypeExact];

#pragma mark PermissiveResearchDelegate

-(void)searchCompletedWithResults:(NSArray *)results
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.foundElements = results;
        [self.tableView reloadData];
    });
}
```

### Create your first search operation
```objective-

    [[ScoringOperationQueue mainQueue] cancelAllOperations]
    HeuristicScoringOperation *ope = [[HeuristicScoringOperation alloc] init];
    ope.searchedString = searchedString;

    SearchCompletionBlock block = ^(NSArray *results) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.foundElements = results;
            NSLog(@"Found elements: %@", results);
        });
    };

    [ope setCustomCompletionBlock:block];
    [[ScoringOperationQueue mainQueue] addOperation:ope];

```

### Actually 3 operations are available, usage depends on the performance you need.
Algorithms complexities are very different.
HeuristicScoringOperation < HeurexactScoringOperation << ExactScoringOperation

```objective-c
ExactScoringOperation
HeuristicScoringOperation
HeurexactScoringOperation
```

### TODO
- Improve keyboard errors tolerance (when a letter is replace by one of its neighbors)
