//
//  IMConversationViewController.m
//  IMDeveloper
//
//  Created by mac on 14-12-9.
//  Copyright (c) 2014年 IMSDK. All rights reserved.
//

#import "IMConversationViewController.h"
#import "IMUserDialogViewController.h"
#import "IMDefine.h"
#import "IMGroupDialogViewController.h"
#import "IMUserInformationViewController.h"

//IMSDK Headers
#import "IMRecentContactsView.h"
#import "IMMyself+RecentContacts.h"
#import "IMMyself+Relationship.h"
#import "IMRecentGroupsView.h"
#import "IMMyself+Group.h"
#import "IMMyself+RecentGroups.h"
#import "IMSDK+CustomUserInfo.h"
#import "IMSDK+MainPhoto.h"

@interface IMConversationViewController ()<IMRecentContactsViewDelegate, IMRecentContactsViewDatasource, UIAlertViewDelegate, IMRecentGroupsViewDatasource, IMRecentGroupsViewDelegate>

@end

@implementation IMConversationViewController {
    IMRecentContactsView *_recentContactsView;
    IMRecentGroupsView *_recentGroupsView;
    
    UIBarButtonItem *_rightBarButtonItem;
    
    NSString *_selectedCustomUserID;
    BOOL _showGroupMessage;
    BOOL _alertClicked;
}

- (void)dealloc
{
    [_recentContactsView setDelegate:nil];
    [_recentContactsView setDataSource:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        [self setTitle:@"消息"];
        [_titleLabel setText:@"消息"];
        [[self tabBarItem] setImage:[UIImage imageNamed:@"IM_conversation_normal.png"]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginStatusChanged:) name:IMLoginStatusChangedNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:IMGroupListDidInitializeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:IMRelationshipDidInitializeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:IMReceiveUserMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:IMUnReadMessageChangedNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"群消息" style:UIBarButtonItemStylePlain target:self action:@selector(rightBarButtonItemClick:)];
    
    [[self navigationItem] setRightBarButtonItem:_rightBarButtonItem];
    
    _recentContactsView = [[IMRecentContactsView alloc] initWithFrame:CGRectMake(0, 0, 320, [[self view] height] - 114)];
    
    [_recentContactsView setDataSource:self];
    [_recentContactsView setDelegate:self];
    [[self view] addSubview:_recentContactsView];
    
    _recentGroupsView = [[IMRecentGroupsView alloc] initWithFrame:[_recentContactsView frame]];
    
    [_recentGroupsView setDataSource:self];
    [_recentGroupsView setDelegate:self] ;
    [[self view] addSubview:_recentGroupsView];
    [_recentGroupsView setHidden:YES];
}

- (void)rightBarButtonItemClick:(id)sender {
    if (sender != _rightBarButtonItem) {
        return;
    }
    
    _showGroupMessage = !_showGroupMessage;
    
    if (!_showGroupMessage) {
        [_rightBarButtonItem setTitle:@"群消息"];
        [_recentGroupsView setHidden:YES];
        [_recentContactsView setHidden:NO];
    } else {
        [_rightBarButtonItem setTitle:@"个人消息"];
        [_recentGroupsView setHidden:NO];
        [_recentContactsView setHidden:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self checkLoginStatus];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)checkLoginStatus {
    switch ([g_pIMMyself loginStatus]) {
        case IMMyselfLoginStatusLogined:
        {
            [_titleLabel setText:@"消息"];
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        }
            break;
        case IMMyselfLoginStatusLogouting:
        {
            [_titleLabel setText:@"正在注销..."];
        }
            break;
        case IMMyselfLoginStatusNone:
        {
            [_titleLabel setText:@"消息(未连接)"];
        }
            break;
        case IMMyselfLoginStatusAutoLogining:
        case IMMyselfLoginStatusLogining:
        {
            [_titleLabel setText:@"连接中..."];
        }
            break;
        case IMMyselfLoginStatusReconnecting:
        {
            [_titleLabel setText:@"正在重连..."];
        }
            break;
        default:
            break;
    }
    
    [_recentContactsView reloadData];
    [_recentGroupsView reloadData];
    [self setBadge];
}

- (void)setBadge {
    NSInteger unreadCount = [g_pIMMyself unreadChatMessageCount] + [g_pIMMyself unreadGroupChatMessageCount];
    
    if (unreadCount) {
        [[self tabBarItem] setBadgeValue:[NSString stringWithFormat:@"%ld",(long)unreadCount]];
    } else {
        [[self tabBarItem] setBadgeValue:nil];
    }
}


#pragma mark - IMRecentContactView delegate

- (UIImage *)recentContactsView:(IMRecentContactsView *)recentContactsView imageForIndex:(NSInteger)index {
    NSString *customUserID = [[g_pIMMyself recentContacts] objectAtIndex:index];
    
    UIImage *image = [g_pIMSDK mainPhotoOfUser:customUserID];
    
    if (image == nil) {
        NSString *customInfo = [g_pIMSDK customUserInfoWithCustomUserID:customUserID];
        
        NSArray *customInfoArray = [customInfo componentsSeparatedByString:@"\n"];
        NSString *sex = nil;
        
        if ([customInfoArray count] > 0) {
            sex = [customInfoArray objectAtIndex:0];
        }
        
        if ([sex isEqualToString:@"女"]) {
            image = [UIImage imageNamed:@"IM_head_female.png"];
        } else {
            image = [UIImage imageNamed:@"IM_head_male.png"];
        }
    }
    
    return image;
}

- (void)recentContactsView:(IMRecentContactsView *)recentContactView didSelectRowWithCustomUserID:(NSString *)customUserID {
    for (UIViewController *controller in [[self navigationController] viewControllers]) {
        if ([controller isKindOfClass:[IMUserDialogViewController class]]) {
            return;
        }
    }
    
    _selectedCustomUserID = customUserID;
    
    if (![g_pIMMyself isMyFriend:customUserID] && ![[g_pIMMyself customUserID] isEqualToString:customUserID]) {
        //if is not friend, enter information controller
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"你们还不是好友，需要先加他为好友" message:nil delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        
        [alertView setTag:1000];
        [alertView show];
        return;
    }
    
    [g_pIMMyself clearUnreadChatMessageWithUser:customUserID];
    [self setBadge];
    
    IMUserDialogViewController *controller = [[IMUserDialogViewController alloc] init];
    
    [controller setCustomUserID:customUserID];
    [controller setHidesBottomBarWhenPushed:YES];
    [[self navigationController] pushViewController:controller animated:YES];
}

- (void)recentContactsView:(IMRecentContactsView *)recentContactView didDeleteRowWithCustomUserID:(NSString *)customUserID {
    [self reloadData];
}


#pragma mark - IMRecentGroupsView delegate

- (void)recentGroupsView:(IMRecentGroupsView *)recentGroupsView didSelectRowWithGroupID:(NSString *)groupID {
    for (UIViewController *controller in [[self navigationController] viewControllers]) {
        if ([controller isKindOfClass:[IMGroupDialogViewController class]]) {
            return;
        }
    }
    
    if (![g_pIMMyself isMyGroup:groupID]) {
        //if is not friend, enter information controller
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"你不是群成员，或你已经被移出该群" message:nil delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        
        [alertView show];
        return;
    }
    
    [g_pIMMyself clearUnreadGroupChatMessageWithGroupID:groupID];
    [self setBadge];
    
    IMGroupDialogViewController *controller = [[IMGroupDialogViewController alloc] init];
    
    [controller setGroupID:groupID];
    [controller setHidesBottomBarWhenPushed:YES];
    [[self navigationController] pushViewController:controller animated:YES];
}

- (void)recentGroupsView:(IMRecentGroupsView *)recentGroupsView didDeleteRowWithGroupID:(NSString *)groupID {
    [self reloadData];
}


#pragma mark - alertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (_alertClicked) {
        return;
    }
    
    if ([alertView tag] == 1000) {
        
        _alertClicked = YES;
        
        IMUserInformationViewController *controller = [[IMUserInformationViewController alloc] init];
        
        [controller setCustomUserID:_selectedCustomUserID];
        [controller setHidesBottomBarWhenPushed:YES];
        [[self navigationController] pushViewController:controller animated:YES];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    _alertClicked = NO;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


#pragma mark - notification

- (void)loginStatusChanged:(NSNotification *)notification {
    [self checkLoginStatus];
}

- (void)reloadData {
    [self checkLoginStatus];
}

@end
