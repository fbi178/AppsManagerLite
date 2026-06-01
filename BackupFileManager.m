#import "BackupFileManager.h"
#import <zlib.h>

#define kBackupRoot @"/var/mobile/Library/BoBoManager"
#define kBackupListFile @"Backups.plist"

// 简单 ZIP 工具（用 iOS 自带 zlib）
@interface ZipUtil : NSObject
+ (BOOL)zipContentsOfDirectory:(NSString *)dirPath toFile:(NSString *)zipPath;
+ (BOOL)unzipFile:(NSString *)zipPath toDirectory:(NSString *)dirPath;
@end

@implementation ZipUtil

+ (BOOL)zipContentsOfDirectory:(NSString *)dirPath toFile:(NSString *)zipPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableData *zipData = [NSMutableData data];
    NSMutableArray *entries = [NSMutableArray array];
    
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:dirPath];
    NSString *relPath;
    while ((relPath = [e nextObject])) {
        NSString *fullPath = [dirPath stringByAppendingPathComponent:relPath];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) {
            relPath = [relPath stringByAppendingString:@"/"];
        }
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        NSData *fileData = isDir ? [NSData data] : [NSData dataWithContentsOfFile:fullPath];
        
        // Local file header
        uint32_t crc = (uint32_t)crc32(0, fileData.bytes, (uInt)fileData.length);
        NSData *compressed = [self deflateData:fileData];
        
        NSMutableData *header = [NSMutableData data];
        [self writeU32:0x04034b50 toData:header];  // local file header signature
        [self writeU16:20 toData:header];           // version needed
        [self writeU16:0 toData:header];            // flags
        [self writeU16:8 toData:header];            // compression method (deflate)
        [self writeU16:0 toData:header];            // mod time
        [self writeU16:0 toData:header];            // mod date
        [self writeU32:crc toData:header];          // crc32
        [self writeU32:(uint32_t)compressed.length toData:header]; // compressed size
        [self writeU32:(uint32_t)fileData.length toData:header];   // uncompressed size
        NSData *nameData = [relPath dataUsingEncoding:NSUTF8StringEncoding];
        [self writeU16:(uint16_t)nameData.length toData:header];
        [self writeU16:0 toData:header]; // extra field length
        [header appendData:nameData];
        
        uint32_t offset = (uint32_t)zipData.length;
        [entries addObject:@{@"header": header, @"offset": @(offset), @"name": relPath}];
        [zipData appendData:header];
        [zipData appendData:compressed];
    }
    
    // Central directory
    uint32_t cdOffset = (uint32_t)zipData.length;
    uint32_t cdSize = 0;
    for (NSDictionary *entry in entries) {
        NSMutableData *cd = [NSMutableData data];
        [self writeU32:0x02014b50 toData:cd];
        [self writeU16:20 toData:cd];
        [self writeU16:20 toData:cd];
        [self writeU16:0 toData:cd];
        [self writeU16:8 toData:cd];
        [self writeU16:0 toData:cd];
        [self writeU16:0 toData:cd];
        NSData *hdr = entry[@"header"];
        // Copy crc + sizes from local header (bytes 14-29)
        [cd appendData:[hdr subdataWithRange:NSMakeRange(14, 12)]];
        NSData *nameData = [entry[@"name"] dataUsingEncoding:NSUTF8StringEncoding];
        [self writeU16:(uint16_t)nameData.length toData:cd];
        [self writeU16:0 toData:cd];
        [self writeU16:0 toData:cd];
        [self writeU32:[entry[@"offset"] unsignedIntValue] toData:cd];
        [cd appendData:nameData];
        [zipData appendData:cd];
        cdSize += cd.length;
    }
    
    // End of central directory
    NSMutableData *eocd = [NSMutableData data];
    [self writeU32:0x06054b50 toData:eocd];
    [self writeU16:0 toData:eocd];
    [self writeU16:0 toData:eocd];
    [self writeU16:(uint16_t)entries.count toData:eocd];
    [self writeU16:(uint16_t)entries.count toData:eocd];
    [self writeU32:cdSize toData:eocd];
    [self writeU32:cdOffset toData:eocd];
    [self writeU16:0 toData:eocd];
    [zipData appendData:eocd];
    
    return [zipData writeToFile:zipPath atomically:YES];
}

+ (NSData *)deflateData:(NSData *)data {
    if (data.length == 0) return data;
    z_stream strm = {0};
    deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY);
    strm.avail_in = (uInt)data.length;
    strm.next_in = (Bytef *)data.bytes;
    NSMutableData *out = [NSMutableData dataWithLength:data.length + 64];
    do {
        strm.avail_out = (uInt)(out.length - strm.total_out);
        strm.next_out = out.mutableBytes + strm.total_out;
        deflate(&strm, Z_FINISH);
    } while (strm.avail_out == 0);
    out.length = strm.total_out;
    deflateEnd(&strm);
    return out;
}

+ (BOOL)unzipFile:(NSString *)zipPath toDirectory:(NSString *)dirPath {
    NSData *data = [NSData dataWithContentsOfFile:zipPath];
    if (!data || data.length < 22) return NO;
    
    // Find EOCD
    const uint8_t *bytes = data.bytes;
    NSUInteger len = data.length;
    uint32_t cdOffset = 0, cdSize = 0, totalEntries = 0;
    for (NSInteger i = len - 22; i >= 0; i--) {
        if (bytes[i] == 0x50 && bytes[i+1] == 0x4b && bytes[i+2] == 0x05 && bytes[i+3] == 0x06) {
            cdSize = *(uint32_t *)(bytes + i + 12);
            cdOffset = *(uint32_t *)(bytes + i + 16);
            totalEntries = *(uint16_t *)(bytes + i + 10);
            break;
        }
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Parse central directory
    uint32_t pos = cdOffset;
    for (int i = 0; i < totalEntries && pos < len; i++) {
        if (bytes[pos] != 0x50 || bytes[pos+1] != 0x4b) break;
        uint16_t nameLen = *(uint16_t *)(bytes + pos + 28);
        uint32_t localOff = *(uint32_t *)(bytes + pos + 42);
        uint32_t compSize = *(uint32_t *)(bytes + pos + 20);
        
        NSString *name = [[NSString alloc] initWithBytes:bytes+pos+46 length:nameLen encoding:NSUTF8StringEncoding];
        pos += 46 + nameLen;
        
        if (!name || [name hasSuffix:@"/"]) continue; // skip directories
        
        // Read local file header
        uint32_t lp = localOff;
        uint16_t localNameLen = *(uint16_t *)(bytes + lp + 26);
        uint16_t localExtraLen = *(uint16_t *)(bytes + lp + 28);
        uint32_t dataOff = lp + 30 + localNameLen + localExtraLen;
        
        NSData *compData = [data subdataWithRange:NSMakeRange(dataOff, compSize)];
        NSData *decomp = [self inflateData:compData];
        
        NSString *outPath = [dirPath stringByAppendingPathComponent:name];
        [[NSFileManager defaultManager] createDirectoryAtPath:[outPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [decomp writeToFile:outPath atomically:YES];
    }
    return YES;
}

+ (NSData *)inflateData:(NSData *)data {
    if (data.length == 0) return data;
    z_stream strm = {0};
    inflateInit2(&strm, -15);
    strm.avail_in = (uInt)data.length;
    strm.next_in = (Bytef *)data.bytes;
    NSMutableData *out = [NSMutableData dataWithLength:data.length * 5];
    int ret;
    do {
        strm.avail_out = (uInt)(out.length - strm.total_out);
        strm.next_out = out.mutableBytes + strm.total_out;
        ret = inflate(&strm, Z_NO_FLUSH);
    } while (ret == Z_OK && strm.avail_out == 0);
    out.length = strm.total_out;
    inflateEnd(&strm);
    return out;
}

+ (void)writeU32:(uint32_t)v toData:(NSMutableData *)d { [d appendBytes:&v length:4]; }
+ (void)writeU16:(uint16_t)v toData:(NSMutableData *)d { [d appendBytes:&v length:2]; }

@end


@implementation BackupFileManager

+ (instancetype)sharedInstance {
    static BackupFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance ensureDirectories];
    });
    return instance;
}

- (void)ensureDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:kBackupRoot]) {
        [fm createDirectoryAtPath:kBackupRoot withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSString *)backupRootPath { return kBackupRoot; }

- (NSString *)backupDirForBundleId:(NSString *)bundleId {
    NSString *dir = [kBackupRoot stringByAppendingPathComponent:bundleId];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)backupFilePathForBundleId:(NSString *)bundleId backupId:(NSString *)backupId {
    return [[self backupDirForBundleId:bundleId] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.adbk", backupId]];
}

- (BOOL)createBackupFileAtPath:(NSString *)destPath
                  fromDataPath:(NSString *)dataPath
                 keychainFiles:(NSArray *)keychainFiles
                      metadata:(NSDictionary *)metadata
                         error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    // 保存元数据到临时目录
    [metadata writeToFile:[dataPath stringByAppendingPathComponent:@"Binfo.plist"] atomically:YES];
    // 追加钥匙串文件
    for (NSString *kc in keychainFiles) {
        if ([fm fileExistsAtPath:kc]) {
            [fm copyItemAtPath:kc toPath:[dataPath stringByAppendingPathComponent:[kc lastPathComponent]] error:nil];
        }
    }
    // ZIP 打包
    BOOL ok = [ZipUtil zipContentsOfDirectory:dataPath toFile:destPath];
    if (!ok && error) {
        *error = [NSError errorWithDomain:@"BackupError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"打包失败"}];
    }
    return ok;
}

- (BOOL)extractBackupFileAtPath:(NSString *)backupPath toTempDir:(NSString *)tempDir error:(NSError **)error {
    [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
    BOOL ok = [ZipUtil unzipFile:backupPath toDirectory:tempDir];
    if (!ok && error) {
        *error = [NSError errorWithDomain:@"BackupError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"解压失败"}];
    }
    return ok;
}

- (NSArray *)loadBackupListForBundleId:(NSString *)bundleId {
    return [NSArray arrayWithContentsOfFile:[[self backupDirForBundleId:bundleId] stringByAppendingPathComponent:kBackupListFile]] ?: @[];
}

- (BOOL)saveBackupList:(NSArray *)list forBundleId:(NSString *)bundleId {
    return [list writeToFile:[[self backupDirForBundleId:bundleId] stringByAppendingPathComponent:kBackupListFile] atomically:YES];
}

@end
