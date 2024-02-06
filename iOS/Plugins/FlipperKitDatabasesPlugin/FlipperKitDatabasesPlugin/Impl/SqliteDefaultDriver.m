#import "SqliteDefaultDriver.h"
#include <Foundation/Foundation.h>
#import "DatabaseExecuteSql.h"
#import "DatabaseGetTableData.h"
#import "DatabaseGetTableInfo.h"
#import "DatabaseGetTableStructure.h"
#import "DatabaseDescriptor.h"
#import <FMDB/FMDB.h>
#import "sqlite3.h"

@interface SqliteDefaultDriver()
@property(nonatomic, strong) NSArray<SqliteDefaultDescriptor *> *databaseDescriptors;
@property(nonatomic, strong) NSString *masterTable;
@end

@implementation SqliteDefaultDriver

- (instancetype)initWithDatabaseDescriptors:(NSArray<SqliteDefaultDescriptor *> *)databaseDescriptors {
    self = [super init];
    if (self) {
        _masterTable = @"sqlite_master";
        _databaseDescriptors = databaseDescriptors;
    }
    return self;
}

// MARK: - DatabaseDriver implementations
- (DatabaseExecuteSqlResponse *)executeSQL:(NSString *)sql withDatabaseDescriptor:(id<DatabaseDescriptor>)databaseDescriptor {
    if (!sql) {
        return nil;
    }
    NSArray<NSString *> *supportedQuery = @[@"SELECT", @"EXPLAINED", @"PRAGMA"];
    NSString *keyword = [self getFirstWord:sql];
    if (![supportedQuery containsObject:keyword]) {
        return nil;
    }
    SqliteDefaultDescriptor *sqliteDescriptor = [self sqliteDescriptor:databaseDescriptor];
    FMDatabase *db = sqliteDescriptor.database;
    if (!sqliteDescriptor || !db) {
        return nil;
    }
    [self openDatabase:db];
    
    FMResultSet *dataResult = [db executeQuery:sql];
    NSMutableArray *columnNames = [NSMutableArray array];
    NSMutableArray<NSArray *> *rows = [NSMutableArray array];
    int columnCount = [dataResult columnCount];
    
    if ([dataResult next]) {
        for (int i = 0; i < columnCount; i++) {
            NSString *columnName = [dataResult columnNameForIndex:i];
            if (columnName) {
                [columnNames addObject:columnName];
            } else {
                [columnNames addObject:[NSNull null]];
            }
        }
    }
    
    do {
        NSMutableArray *row = [NSMutableArray array];
        for (int i = 0; i < columnCount; i++) {
            id field = [dataResult objectForColumnIndex:i];
            if (field) {
                [row addObject:field];
            } else {
                [row addObject:[NSNull null]];
            }
        }
        [rows addObject:row];
    } while ([dataResult next]);
    
    [db close];
    
    return [[DatabaseExecuteSqlResponse alloc] initWithType:@"select" columns:columnNames values:rows insertedId:nil affectedCount:0];
}

- (NSArray<id<DatabaseDescriptor>> *)getDatabases { 
    return _databaseDescriptors;
}

- (DatabaseGetTableDataResponse *)getTableDataWithDatabaseDescriptor:(id<DatabaseDescriptor>)databaseDescriptor forTable:(NSString *)tableName order:(NSString *)order reverse:(BOOL)reverse start:(NSInteger)start count:(NSInteger)count {
    SqliteDefaultDescriptor *sqliteDescriptor = [self sqliteDescriptor:databaseDescriptor];
    FMDatabase *db = sqliteDescriptor.database;
    if (!sqliteDescriptor || !db || !tableName) {
        return nil;
    }
    [self openDatabase:db];
    
    NSString *orderBy = order != NULL ? [NSString stringWithFormat:@"%@ %@", order, reverse ? @"DESC" : @"ASC"] : NULL;
    NSString *query;
    if (orderBy) {
        query = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@ LIMIT %ld, %ld", tableName, orderBy, start, count];
    } else {
        query = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT %ld, %ld", tableName, start, count];
    }
    
    NSString *countQuery = [NSString stringWithFormat:@"SELECT COUNT(*) AS count FROM %@", tableName];
    FMResultSet *countResult = [db executeQuery:countQuery];
    NSUInteger total = 0;
    if ([countResult next]) {
        total = [countResult longLongIntForColumnIndex:0];
    }
    
    FMResultSet *dataResult = [db executeQuery:query];
    NSMutableArray *columnNames = [NSMutableArray array];
    NSMutableArray<NSArray *> *rows = [NSMutableArray array];
    int columnCount = [dataResult columnCount];
    
    if ([dataResult next]) {
        for (int i = 0; i < columnCount; i++) {
            NSString *columnName = [dataResult columnNameForIndex:i];
            if (columnName) {
                [columnNames addObject:columnName];
            } else {
                [columnNames addObject:[NSNull null]];
            }
        }
    }
    
    do {
        NSMutableArray *row = [NSMutableArray array];
        for (int i = 0; i < columnCount; i++) {
            id field = [dataResult objectForColumnIndex:i];
            if (field) {
                [row addObject:field];
            } else {
                [row addObject:[NSNull null]];
            }
        }
        [rows addObject:row];
    } while ([dataResult next]);
    
    [db close];
    return [[DatabaseGetTableDataResponse alloc] initWithColumns:columnNames
                                                          values:rows
                                                           start:start
                                                           count:count
                                                           total:total];
}

- (DatabaseGetTableInfoResponse *)getTableInfoWithDatabaseDescriptor:(id<DatabaseDescriptor>)databaseDescriptor forTable:(NSString *)tableName {
    SqliteDefaultDescriptor *sqliteDescriptor = [self sqliteDescriptor:databaseDescriptor];
    FMDatabase *db = sqliteDescriptor.database;
    if (!sqliteDescriptor || !db || !tableName) {
        return nil;
    }
    [self openDatabase:db];
    NSString *statement = [NSString stringWithFormat:@"SELECT sql FROM %@ WHERE name = %@", _masterTable, tableName];
    FMResultSet *resultSet = [db executeQuery:statement];
    if ([resultSet next]) {
        return [[DatabaseGetTableInfoResponse alloc] initWithDefinition:[resultSet stringForColumnIndex:0]];
    }
    [db close];
    return nil;
}

- (NSArray<NSString *> *)getTableNames:(id<DatabaseDescriptor>)databaseDescriptor {
    SqliteDefaultDescriptor *sqliteDescriptor = [self sqliteDescriptor:databaseDescriptor];
    FMDatabase *db = sqliteDescriptor.database;
    if (!sqliteDescriptor || !db) {
        return nil;
    }
    [self openDatabase:db];
    NSString *statement = [NSString stringWithFormat:@"SELECT name FROM %@ WHERE type IN ('table', 'view')", _masterTable];
    FMResultSet *resultSet = [db executeQuery:statement];
    NSMutableArray *tables = [NSMutableArray array];
    while ([resultSet next]) {
        NSString *tableName = [resultSet stringForColumnIndex:0];
        if (tableName) {
            [tables addObject:tableName];
        } else {
            [tables addObject:[NSNull null]];
        }
    }
    [db close];
    return tables;
}

- (DatabaseGetTableStructureResponse *)getTableStructureWithDatabaseDescriptor:(id<DatabaseDescriptor>)databaseDescriptor forTable:(NSString *)tableName {
    SqliteDefaultDescriptor *sqliteDescriptor = [self sqliteDescriptor:databaseDescriptor];
    FMDatabase *db = sqliteDescriptor.database;
    if (!sqliteDescriptor || !db || !tableName) {
        return nil;
    }
    [self openDatabase:db];
    
    NSString *structureStatement = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tableName];
    NSString *foreignKeysStatement = [NSString stringWithFormat:@"PRAGMA foreign_key_list(%@)", tableName];
    NSString *indexesStatement = [NSString stringWithFormat:@"PRAGMA index_list(%@)", tableName];
    FMResultSet *structureResult = [db executeQuery:structureStatement];
    FMResultSet *foreignKeyResult = [db executeQuery:foreignKeysStatement];
    FMResultSet *indexesResult = [db executeQuery:indexesStatement];
    
    NSArray<NSString *> *structureColumns = @[@"column_name", @"data_type", @"nullable", @"default", @"primary_key", @"foreign_key"];
    NSMutableArray<NSArray *> *structureValues = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSString*> *foreignKeyValues = [NSMutableDictionary dictionary];
    
    while ([foreignKeyResult next]) {
        NSString *foreignKeyKey = [foreignKeyResult stringForColumn:@"from"];
        NSString *foreignKeyValue = [NSString stringWithFormat:@"%@(%@)", [foreignKeyResult stringForColumn:@"table"], [foreignKeyResult stringForColumn:@"to"]];
        [foreignKeyValues setObject:foreignKeyValue forKey:foreignKeyKey];
    }
    
    while ([structureResult next]) {
        NSString *columnName = [structureResult stringForColumn:@"name"];
        NSString *foreignKey = [foreignKeyValues objectForKey:columnName];
        
        NSArray *fieldStructureValue = @[
            columnName ?: [NSNull null],
            [structureResult stringForColumn:@"type"] ?: [NSNull null],
            [NSNumber numberWithBool:[structureResult intForColumn:@"notnull"] == 0], // true if Nullable, false otherwise
            [structureResult objectForColumn:@"dflt_value"] ?: [NSNull null],
            [NSNumber numberWithBool:[structureResult intForColumn:@"pk"] == 1],
            foreignKey ?: [NSNull null]
        ];
        [structureValues addObject:fieldStructureValue];
    }
    
    NSArray<NSString *> *indexesColumns = @[@"index_name", @"unique", @"indexed_column_name"];
    NSMutableArray<NSArray *> *indexesValue = [NSMutableArray array];
    while ([indexesResult next]) {
        NSMutableArray *indexedColumnNames = [NSMutableArray array];
        NSString *indexName = [indexesResult stringForColumn:@"name"];
        NSString *queryIndexName = [NSString stringWithFormat:@"PRAGMA index_info(%@)", indexName];
        FMResultSet *indexInfoResult = [db executeQuery:queryIndexName];
        while ([indexInfoResult next]) {
            NSString *indexInfoName = [indexInfoResult stringForColumn:@"name"];
            if (indexInfoName) {
                [indexedColumnNames addObject:indexInfoName];
            } else {
                [indexedColumnNames addObject:[NSNull null]];
            }
        }
        [indexesValue addObject:@[
            indexName ?: [NSNull null],
            [NSNumber numberWithBool:[indexesResult intForColumn:@"unique"] == 1],
            [indexedColumnNames componentsJoinedByString:@","]
        ]];
    }
    
    [db close];
    return [[DatabaseGetTableStructureResponse alloc] initWithStructureColumns:structureColumns
                                                               structureValues:structureValues
                                                                indexesColumns:indexesColumns
                                                                 indexesValues:indexesValue];
}

// MARK: - Private helpers
- (NSString *)getFirstWord:(NSString *)sql {
    NSString *trimmedSql = [sql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *words = [trimmedSql componentsSeparatedByString:@" "];
    if (words.count > 0) {
        return words[0];
    }
    return nil;
}

- (SqliteDefaultDescriptor *)sqliteDescriptor:(id<DatabaseDescriptor>)descriptor {
    for (int i = 0; i < _databaseDescriptors.count; i++) {
        if ([[_databaseDescriptors[i] name] isEqualToString:[descriptor name]]) {
            return _databaseDescriptors[i];
        }
    }
    return nil;
}

- (void)openDatabase:(FMDatabase *)database {
    if (![database openWithFlags:SQLITE_OPEN_READONLY]) {
        NSLog(@"cannot open db");
    }
}

@end
