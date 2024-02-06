#import "SqliteDefaultDescriptor.h"
#import <Foundation/Foundation.h>

@interface SqliteDefaultDescriptor ()
@property(strong, nonatomic) NSURL *fileUrl;
@property(strong, nonatomic) FMDatabase *database;
@end

@implementation SqliteDefaultDescriptor

-(instancetype)initWithUrl:(NSURL *)url {
    self = [super init];
    if (self) {
        _fileUrl = url;
    }
    return self;
}

- (NSString *)name {
    return [_fileUrl lastPathComponent];
}

-(FMDatabase *)database {
    if (!_database) {
        _database = [[FMDatabase alloc] initWithURL:_fileUrl];
    }
    return _database;
}

@end
