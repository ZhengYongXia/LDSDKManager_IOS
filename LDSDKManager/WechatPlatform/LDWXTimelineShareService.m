//
//  LDWXTimelineShareService.m
//  TestThirdPlatform
//
//  Created by ss on 15/8/14.
//  Copyright (c) 2015年 Lede. All rights reserved.
//

#import "LDWXTimelineShareService.h"
#import "WXApi.h"
#import "UIImage+LDSDKShare.h"
#import "LDSDKWXService.h"

@implementation LDWXTimelineShareService

+ (instancetype)sharedService
{
    static LDWXTimelineShareService *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

-(void)shareWithDict:(NSDictionary *)dict onComplete:(void (^)(BOOL, NSError *))complete
{
    if (![WXApi isWXAppInstalled] || ![WXApi isWXAppSupportApi]) {
        NSError *error = [NSError errorWithDomain:@"WXShare" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"请先安装微信客户端", @"NSLocalizedDescription", nil]];
        if (complete) {
            complete(NO, error);
        }
        return;
    }
    
    WXMediaMessage *message = [WXMediaMessage message];
    NSString *title = dict[@"title"];
    NSString *description = dict[@"description"];
    NSString *urlString = dict[@"webpageurl"];
    UIImage *oldImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:dict[@"imageurl"]]]];
    message.title = title;
    message.description = description;
    
    if(urlString){
        if (oldImage) {
            [message setThumbImage:oldImage];
        }
        
        WXWebpageObject *ext = [WXWebpageObject object];
        NSString *link = urlString;
        ext.webpageUrl = [link stringByAppendingFormat:[link rangeOfString:@"?"].location == NSNotFound ? @"?shareMode=%lu" : @"&shareMode=%lu",(unsigned long)1];
        
        message.mediaObject = ext;
    } else if (oldImage) { //分享图片
        //指定缩略图，
        UIImage *image = oldImage;
        CGSize thumbSize = image.size;
        UIImage *thumbImage = image;
        if (image.scale > 1.0) {
            thumbImage = [image LDSDKShare_resizedImage:image.size interpolationQuality:kCGInterpolationDefault];
        }
        
        NSData *thumbData = UIImageJPEGRepresentation(thumbImage, 0.0);
        while (thumbData.length > 32*1024) { //不能超过32K
            thumbSize =CGSizeMake(thumbSize.width/2.0, thumbSize.height/2.0);
            thumbImage = [thumbImage LDSDKShare_resizedImage:thumbSize interpolationQuality:kCGInterpolationDefault];
            thumbData = UIImageJPEGRepresentation(thumbImage, 0.0);
        }
        [message setThumbData:thumbData];
        
        WXImageObject *ext = [WXImageObject object];
        ext.imageData = UIImageJPEGRepresentation(image, 1.0);
        message.mediaObject = ext;
    } else {
        NSAssert(0, @"WechatTimelien contentItem Error");
    }
    
    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = WXSceneTimeline;
    [[LDSDKWXService defaultService] sendReq:req callback:^(BaseResp *resp) {
        if ([resp isKindOfClass:[SendMessageToWXResp class]]) {
            [LDWXTimelineShareService handleShareResultInActivity:resp onComplete:complete];
        }
    }];
}


+(void)handleShareResultInActivity:(id)result onComplete:(void (^)(BOOL, NSError *))complete
{
    SendMessageToWXResp *response = (SendMessageToWXResp *)result;
    
    switch (response.errCode) {
        case WXSuccess:
            if (complete) {
                complete(YES, nil);
            }
            
            break;
        case WXErrCodeUserCancel:{
            NSError *error = [NSError errorWithDomain:@"WXTimelineShare" code:-2 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"用户取消分享", @"NSLocalizedDescription", nil]];
            if (complete) {
                complete(NO, error);
            }
        }
            break;
        default:{
            NSError *error = [NSError errorWithDomain:@"WXTimelineShare" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"分享失败", @"NSLocalizedDescription", nil]];
            if (complete) {
                complete(NO, error);
            }
        }
            
            break;
    }
    
}

@end