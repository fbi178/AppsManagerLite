#import "AppTableViewCell.h"
#import "ApplicationItem.h"

@implementation AppTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    // App 图标
    self.appIconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 8, 48, 48)];
    self.appIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.appIconView.layer.cornerRadius = 8;
    self.appIconView.clipsToBounds = YES;
    [self.contentView addSubview:self.appIconView];
    
    // App 名称
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 8, self.contentView.frame.size.width - 92, 22)];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
    self.nameLabel.textColor = [UIColor blackColor];
    [self.contentView addSubview:self.nameLabel];
    
    // Bundle ID
    self.bundleIdLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 30, self.contentView.frame.size.width - 92, 16)];
    self.bundleIdLabel.font = [UIFont systemFontOfSize:11];
    self.bundleIdLabel.textColor = [UIColor grayColor];
    [self.contentView addSubview:self.bundleIdLabel];
    
    // 版本号
    self.versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 46, self.contentView.frame.size.width - 92, 14)];
    self.versionLabel.font = [UIFont systemFontOfSize:11];
    self.versionLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.versionLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.frame.size.width;
    self.nameLabel.frame = CGRectMake(76, 6, width - 92, 22);
    self.bundleIdLabel.frame = CGRectMake(76, 28, width - 92, 16);
    self.versionLabel.frame = CGRectMake(76, 44, width - 92, 14);
}

- (void)configureWithItem:(ApplicationItem *)item {
    self.item = item;
    self.appIconView.image = item.icon ?: [UIImage imageNamed:@"noicon"];
    self.nameLabel.text = item.appName;
    self.bundleIdLabel.text = item.bundleId;
    self.versionLabel.text = [NSString stringWithFormat:@"版本 %@", item.version];
}

@end
