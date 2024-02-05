/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@interface DatabaseGetTableStructureResponse : NSObject

@property(nonatomic, strong, readonly) NSArray<NSString*>* structureColumns;
@property(nonatomic, strong, readonly)
    NSArray<NSArray<id>*>* structureValues;
@property(nonatomic, strong, readonly) NSArray<NSString*>* indexesColumns;
@property(nonatomic, strong, readonly)
    NSArray<NSArray<id>*>* indexesValues;

- (instancetype)
    initWithStructureColumns:(NSArray<NSString*>*)structureColumns
             structureValues:(NSArray<NSArray<id>*>*)structureValues
              indexesColumns:(NSArray<NSString*>*)indexesColumns
               indexesValues:(NSArray<NSArray<id>*>*)indexesValues;

@end

@interface DatabaseGetTableStructureRequest : NSObject

@property(nonatomic, assign, readonly) NSInteger databaseId;
@property(nonatomic, copy, readonly) NSString* table;

- (instancetype)initWithDatabaseId:(NSInteger)databaseId table:(NSString*)table;
+ (DatabaseGetTableStructureRequest*)getTableStructureRequestFromDictionary:
    (NSDictionary*)dictionary;

@end
