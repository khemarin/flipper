#import <Foundation/Foundation.h>
#import "DatabaseDescriptor.h"
#import <FMDB/FMDatabase.h>

@interface SqliteDefaultDescriptor : NSObject<DatabaseDescriptor>

@property(strong, nonatomic, readonly) NSURL *fileUrl;
@property(strong, nonatomic, readonly) FMDatabase *database;

-(instancetype)initWithUrl:(NSURL *)url;
@end

