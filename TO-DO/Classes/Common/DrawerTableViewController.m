//
//  JVLeftDrawerTableViewController.m
//  JVFloatingDrawer
//
//  Created by Julian Villella on 2015-01-15.
//  Copyright (c) 2015 JVillella. All rights reserved.
//

#import "AppDelegate.h"
#import "CalendarViewController.h"
#import "DGActivityIndicatorView.h"
#import "DrawerTableViewCell.h"
#import "DrawerTableViewController.h"
#import "GCDQueue.h"
#import "HomeViewController.h"
#import "JVFloatingDrawerView.h"
#import "LoginViewController.h"
#import "Masonry.h"
#import "SGSyncManager.h"

typedef NS_ENUM(NSInteger, DrawerItem) {
    DrawerItemHome,
    DrawerItemCalendar,
    DrawerItemOverview,
    DrawerItemProfile,
    DrawerItemTimeline
};

static NSString *const kDataKeyTitle = @"title";
static NSString *const kDataKeyIcon = @"icon";
static NSString *const kDataKeyClass = @"class";

static NSString *const kDrawerCellReuseIdentifier = @"Identifier";
static NSInteger const kRowHeight = 40;
static NSInteger const kBottomViewHeight = 70;
static CGFloat const kSyncIndicatorSize = 15;

@interface
DrawerTableViewController ()
@property(nonatomic, readwrite, strong) SGSyncManager *dataManager;
@property(nonatomic, readwrite, strong) NSArray<NSDictionary *> *dataArray;

@property(nonatomic, readwrite, strong) UIView *bottomView;
@property(nonatomic, readwrite, strong) DGActivityIndicatorView *indicatorView;
@property(nonatomic, readwrite, strong) UIButton *leftBottomButton;
@property(nonatomic, readwrite, strong) UIButton *centerBottomButton;
@property(nonatomic, readwrite, strong) UIButton *rightBottomButton;
@end

@implementation DrawerTableViewController
#pragma mark - localization

- (void)localizeStrings {
    _dataArray = @[
            @{kDataKeyTitle: NSLocalizedString(@"Home", nil),
                    kDataKeyIcon: @"",
                    kDataKeyClass: [HomeViewController class]},
//            @{kDataKeyTitle: NSLocalizedString(@"Calendar", nil),
//                    kDataKeyIcon: @"",
//                    kDataKeyClass: [CalendarViewController class]}
    ];
    
    [_leftBottomButton setTitle:NSLocalizedString(@"SYNC", nil) forState:UIControlStateNormal];
    [_leftBottomButton setTitle:NSLocalizedString(@"SYNCING", nil) forState:UIControlStateDisabled];
    [_centerBottomButton setTitle:NSLocalizedString(@"SETTINGS", nil) forState:UIControlStateNormal];
    [_rightBottomButton setTitle:NSLocalizedString(@"LOGOUT", nil) forState:UIControlStateNormal];
}

#pragma mark - accessors

- (CGFloat)tableViewInsetTop {
    return kScreenHeight * 0.18;
}

#pragma mark - initial

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
    [self bindConstraints];
    [self localizeStrings];

#ifdef ENABLE_AUTOMATIC_SYNC
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged) name:kRealReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needsToSyncAutomatically) name:kTodosChangedNotification object:nil];
#endif
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:DrawerItemHome inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)setup {
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.contentInset = UIEdgeInsetsMake([self tableViewInsetTop], 0.0, 0.0, 0.0);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.bounces = NO;
    self.tableView.clipsToBounds = NO;
    self.tableView.rowHeight = kRowHeight;
    [self.tableView registerClass:[DrawerTableViewCell class] forCellReuseIdentifier:kDrawerCellReuseIdentifier];
    self.clearsSelectionOnViewWillAppear = NO;
    
    _dataManager = [SGSyncManager sharedInstance];
    
    __weak UIImageView *bottomContainerView = [AppDelegate globalDelegate].drawerViewController.drawerView.backgroundImageView;
    [bottomContainerView setUserInteractionEnabled:YES];
    
    _bottomView = [UIView new];
    [bottomContainerView addSubview:_bottomView];
    
    UIColor *bottomItemColor = ColorWithRGB(0x999999);
    UIFont *bottomItemFont = [SGHelper themeFontWithSize:13];
    
    _indicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeRotatingTrigons tintColor:bottomItemColor size:kSyncIndicatorSize];
    [_bottomView addSubview:_indicatorView];
    
    _leftBottomButton = [UIButton new];
    _leftBottomButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _leftBottomButton.titleLabel.font = bottomItemFont;
    [_leftBottomButton setTitleColor:bottomItemColor forState:UIControlStateNormal];
    [_leftBottomButton addTarget:self action:@selector(syncButtonDidPress) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_leftBottomButton];
    
    _centerBottomButton = [UIButton new];
    _centerBottomButton.titleLabel.font = bottomItemFont;
    [_centerBottomButton setTitleColor:bottomItemColor forState:UIControlStateNormal];
    [_centerBottomButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_centerBottomButton];
    
    _rightBottomButton = [UIButton new];
    _rightBottomButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    _rightBottomButton.titleLabel.font = bottomItemFont;
    [_rightBottomButton setTitleColor:bottomItemColor forState:UIControlStateNormal];
    [_rightBottomButton addTarget:self action:@selector(logOut) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_rightBottomButton];
    
    [bottomContainerView bringSubviewToFront:_bottomView];
}

- (void)bindConstraints {
    __weak typeof(self) weakSelf = self;
    [_bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.offset(0);
        make.top.offset(kScreenHeight - kBottomViewHeight);
        make.height.offset(kBottomViewHeight);
        make.width.offset(kScreenWidth);
    }];
    
    CGFloat spaceFromView = [DrawerTableViewCell leftSpaceFromView];
    [_leftBottomButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.offset(spaceFromView);
        make.centerY.offset(0);
        make.width.offset(70);
        make.height.offset(30);
    }];
    
    // Mark: 这个菊花有时候位置不正常
    [_indicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(weakSelf.leftBottomButton.mas_left).offset(-2);
        make.centerY.equalTo(weakSelf.leftBottomButton);
        make.height.width.offset(kSyncIndicatorSize);
    }];
    
    [_centerBottomButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.offset(0);
        make.baseline.equalTo(weakSelf.leftBottomButton);
        make.baseline.equalTo(weakSelf.leftBottomButton);
        make.width.height.equalTo(weakSelf.leftBottomButton);
    }];
    
    [_rightBottomButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.offset(-spaceFromView);
        make.baseline.equalTo(weakSelf.leftBottomButton);
        make.width.height.equalTo(weakSelf.leftBottomButton);
    }];
}

#pragma mark - sync button

- (void)syncButtonDidPress {
    [self synchronize:SyncModeManually];
}

#pragma mark - synchronize

- (void)synchronize:(SyncMode)syncType {
    __weak typeof(self) weakSelf = self;
    [[GCDQueue globalQueueWithLevel:DISPATCH_QUEUE_PRIORITY_DEFAULT] sync:^{
        if ([[weakSelf.dataManager class] isSyncing]) return;
        
        [weakSelf isSyncing:YES];
        [weakSelf.dataManager synchronize:syncType complete:^(BOOL succeed) {
            [weakSelf isSyncing:NO];
        }];
    }];
}

- (void)isSyncing:(BOOL)isBegin {
    if (isBegin)
        [_indicatorView startAnimating];
    else
        [_indicatorView stopAnimating];
    
    [_leftBottomButton setEnabled:!isBegin];
}

- (void)needsToSyncAutomatically {
    [self synchronize:SyncModeAutomatically];
}

#pragma mark - show settings

- (void)showSettings {
    DDLogDebug(@"%s", __func__);
}

#pragma mark - log out

- (void)logOut {
    [LCUser logOut];
    [[AppDelegate globalDelegate] toggleDrawer:self animated:YES];
    LoginViewController *loginViewController = [LoginViewController new];
    [[AppDelegate globalDelegate] switchRootViewController:loginViewController isNavigation:NO];
}

#pragma mark - tableview

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return _dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DrawerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDrawerCellReuseIdentifier forIndexPath:indexPath];
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(DrawerTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *data = _dataArray[indexPath.row];
    [cell setTitle:data[kDataKeyTitle]];
    if ([data[kDataKeyIcon] isKindOfClass:[UIImage class]]) [cell setIcon:data[kDataKeyIcon]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *destinationViewController = [_dataArray[indexPath.row][kDataKeyClass] new];
    
    [[AppDelegate globalDelegate] switchRootViewController:destinationViewController isNavigation:YES];
    [[AppDelegate globalDelegate] toggleDrawer:self animated:YES];
}

#pragma mark - sync silently when network become reachable

- (void)networkChanged {
    if (!isNetworkUnreachable) [self synchronize:SyncModeAutomatically];
}

#pragma mark - release

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end