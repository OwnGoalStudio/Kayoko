//
//  KayokoTagTableViewCell.m
//  Kayoko
//

#import "KayokoTagTableViewCell.h"
#import "KayokoTag.h"
#import "KayokoTagColorFormatter.h"

static CGFloat const kKayokoTagTableViewCellSwatchDiameter = 22.0;
static CGFloat const kKayokoTagTableViewCellSwatchBorderWidth = 1.0;

@interface KayokoTagTableViewCell ()
@property(nonatomic, strong) UIView *colorSwatchView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *hexColorLabel;
@end

@implementation KayokoTagTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self configureSubviews];
    }
    return self;
}

- (void)configureSubviews {
    [self setSelectionStyle:UITableViewCellSelectionStyleDefault];
    [[self contentView] setPreservesSuperviewLayoutMargins:YES];

    _colorSwatchView = [[UIView alloc] init];
    [_colorSwatchView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_colorSwatchView layer] setCornerRadius:kKayokoTagTableViewCellSwatchDiameter / 2.0];
    [[_colorSwatchView layer] setBorderWidth:kKayokoTagTableViewCellSwatchBorderWidth];
    [[self contentView] addSubview:_colorSwatchView];

    _titleLabel = [[UILabel alloc] init];
    [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
    [_titleLabel setTextColor:[UIColor labelColor]];
    [_titleLabel setNumberOfLines:1];
    [[self contentView] addSubview:_titleLabel];

    _hexColorLabel = [[UILabel alloc] init];
    [_hexColorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_hexColorLabel setFont:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]];
    [_hexColorLabel setTextColor:[UIColor secondaryLabelColor]];
    [_hexColorLabel setNumberOfLines:1];
    [[self contentView] addSubview:_hexColorLabel];

    UILayoutGuide *margins = [[self contentView] layoutMarginsGuide];
    [NSLayoutConstraint activateConstraints:@[
        [[_colorSwatchView leadingAnchor] constraintEqualToAnchor:[margins leadingAnchor]],
        [[_colorSwatchView centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]],
        [[_colorSwatchView widthAnchor] constraintEqualToConstant:kKayokoTagTableViewCellSwatchDiameter],
        [[_colorSwatchView heightAnchor] constraintEqualToConstant:kKayokoTagTableViewCellSwatchDiameter],

        [[_titleLabel leadingAnchor] constraintEqualToAnchor:[_colorSwatchView trailingAnchor] constant:13.0],
        [[_titleLabel trailingAnchor] constraintEqualToAnchor:[margins trailingAnchor]],
        [[_titleLabel topAnchor] constraintEqualToAnchor:[[self contentView] topAnchor] constant:9.0],

        [[_hexColorLabel leadingAnchor] constraintEqualToAnchor:[_titleLabel leadingAnchor]],
        [[_hexColorLabel trailingAnchor] constraintEqualToAnchor:[_titleLabel trailingAnchor]],
        [[_hexColorLabel topAnchor] constraintEqualToAnchor:[_titleLabel bottomAnchor] constant:2.0],
        [[_hexColorLabel bottomAnchor] constraintLessThanOrEqualToAnchor:[[self contentView] bottomAnchor]
                                                                constant:-8.0]
    ]];
}

- (void)configureWithTag:(KayokoTag *)tag editing:(BOOL)editing {
    [[self titleLabel] setText:[tag title]];
    [[self hexColorLabel] setText:[tag hexColor]];
    [[self colorSwatchView] setBackgroundColor:[KayokoTagColorFormatter visibleColorFromHexColor:[tag hexColor]]];
    [[[self colorSwatchView] layer]
        setBorderColor:[[KayokoTagColorFormatter borderColorFromHexColor:[tag hexColor]] CGColor]];
    [self setAccessoryType:editing ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self setAccessoryType:editing ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator];
}

@end
