#import "PlistEditorController.h"

@interface PlistEditorController ()
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, strong) NSMutableDictionary *plistData;
@property (nonatomic, strong) NSArray *keys;
@end

@implementation PlistEditorController

- (instancetype)initWithPlistPath:(NSString *)path {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _plistPath = path;
        _plistData = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        _keys = [_plistData.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Plist 编辑器";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(savePlist)];
}

- (void)savePlist {
    [self.plistData writeToFile:self.plistPath atomically:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.keys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.keys[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    NSString *key = self.keys[indexPath.section];
    id value = self.plistData[key];
    
    if ([value isKindOfClass:[NSString class]]) {
        cell.textLabel.text = value;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        cell.textLabel.text = [value stringValue];
    } else if ([value isKindOfClass:[NSData class]]) {
        cell.textLabel.text = [NSString stringWithFormat:@"<Data: %lu bytes>", (unsigned long)[value length]];
    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
        cell.textLabel.text = [NSString stringWithFormat:@"<%@: %lu items>", 
                               [value isKindOfClass:[NSArray class]] ? @"Array" : @"Dict",
                               (unsigned long)[value count]];
    } else {
        cell.textLabel.text = [value description];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // TODO: 编辑值
}

@end
