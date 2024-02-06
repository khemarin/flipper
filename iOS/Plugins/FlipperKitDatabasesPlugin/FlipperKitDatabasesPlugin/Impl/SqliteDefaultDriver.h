#import <Foundation/Foundation.h>
#import "DatabaseDriver.h"
#import "SqliteDefaultDescriptor.h"

@protocol DatabaseDescriptor;

@interface SqliteDefaultDriver : NSObject<DatabaseDriver>

@property(nonatomic, strong, readonly) NSArray<SqliteDefaultDescriptor *> *databaseDescriptors;

-(instancetype)initWithDatabaseDescriptors:(NSArray<SqliteDefaultDescriptor *> *)databaseDescriptors;

@end
