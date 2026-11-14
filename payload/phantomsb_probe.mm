// ============================================================
//  phantomsb_probe.mm —— SpringBoard 常驻浮层可行性实测（最小版）
//  目的：验证三件事
//   ① RootHide 的 TweakInject 能否把本 dylib 注入 SpringBoard
//   ② 在 SpringBoard 里自建 UIWindow（高 windowLevel）能否显示在 app 之上、且能被触摸
//   ③ app 被划掉后，这个浮层是否仍然存在（因为宿主是 SpringBoard 而不是 app）
//  日志：/var/mobile/Media/Downloads/phantomsb.txt、/tmp/phantomsb.txt
// ============================================================
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>

static void SBLog(const char* fmt, ...)
{
    va_list ap; va_start(ap, fmt);
    char body[900]; vsnprintf(body, sizeof(body), fmt, ap); va_end(ap);

    time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
    char line[1200];
    snprintf(line, sizeof(line), "%02d:%02d:%02d [sbprobe:%d] %s\n",
             tmv.tm_hour, tmv.tm_min, tmv.tm_sec, (int)getpid(), body);

    const char* paths[2] = { "/var/mobile/Media/Downloads/phantomsb.txt",
                             "/tmp/phantomsb.txt" };
    for (int i = 0; i < 2; i++) {
        FILE* f = fopen(paths[i], "a");
        if (!f) { continue; }
        fputs(line, f);
        fclose(f);
        return;
    }
}

@interface SBBall : UIView
@end

@implementation SBBall
- (instancetype)initWithFrame:(CGRect)f
{
    self = [super initWithFrame:f];
    if (self == nil) { return nil; }
    self.backgroundColor = [UIColor colorWithWhite:0.97 alpha:0.95];
    self.layer.cornerRadius = f.size.width * 0.5f;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:0.62 alpha:0.9].CGColor;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.35f;
    self.layer.shadowRadius = 8.f;
    self.layer.shadowOffset = CGSizeMake(0, 3);

    UILabel* l = [[UILabel alloc] initWithFrame:self.bounds];
    l.text = @"SB";
    l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBlack];
    l.textColor = [UIColor colorWithWhite:0.15 alpha:1];
    l.textAlignment = NSTextAlignmentCenter;
    l.userInteractionEnabled = NO;
    [self addSubview:l];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [self addGestureRecognizer:pan];
    return self;
}
- (void)touchesEnded:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e
{
    [super touchesEnded:t withEvent:e];
    SBLog("ball tapped (UIKit touch reached SpringBoard overlay OK)");
}
- (void)onPan:(UIPanGestureRecognizer*)g
{
    UIView* sup = self.superview;
    if (sup == nil) { return; }
    CGPoint d = [g translationInView:sup];
    CGPoint c = CGPointMake(self.center.x + d.x, self.center.y + d.y);
    CGFloat hw = self.bounds.size.width * 0.5f;
    c.x = MAX(hw + 6, MIN(sup.bounds.size.width - hw - 6, c.x));
    c.y = MAX(hw + 6, MIN(sup.bounds.size.height - hw - 6, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:sup];
}
@end

static UIWindow*      g_win  = nil;
static UIView*        g_host = nil;
static SBBall*        g_ball = nil;
static UILabel*       g_info = nil;

static UIWindowScene* SBPickScene(void)
{
    UIApplication* app = [UIApplication sharedApplication];
    if (app == nil) { return nil; }
    UIWindowScene* fallback = nil;
    for (UIScene* s in app.connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) { continue; }
        UIWindowScene* ws = (UIWindowScene*)s;
        NSString* cls = NSStringFromClass([ws.delegate class]) ?: @"";
        if (fallback == nil) { fallback = ws; }
        if ([cls containsString:@"HomeScreen"]) { return ws; }
    }
    if (fallback == nil) {
        for (UIWindow* w in app.windows) {
            if (w.windowScene != nil) { return w.windowScene; }
        }
    }
    return fallback;
}

static void SBInstall(void)
{
    if (g_win != nil) { g_win.hidden = NO; return; }

    UIWindowScene* scene = SBPickScene();
    if (scene == nil) { SBLog("install: no window scene yet"); return; }

    g_win = [[UIWindow alloc] initWithWindowScene:scene];
    g_win.windowLevel = 20000000.0;
    g_win.backgroundColor = [UIColor clearColor];
    g_win.opaque = NO;

    UIViewController* vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor clearColor];
    g_win.rootViewController = vc;
    g_host = vc.view;

    CGRect r = scene.coordinateSpace.bounds;
    CGFloat bs = 56.f;
    g_ball = [[SBBall alloc] initWithFrame:CGRectMake(r.size.width - bs - 32.f,
                                                      r.size.height * 0.5f, bs, bs)];
    g_ball.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [g_host addSubview:g_ball];

    g_info = [[UILabel alloc] initWithFrame:CGRectMake(16, 60, 420, 90)];
    g_info.numberOfLines = 0;
    g_info.text = [NSString stringWithFormat:@"PHANTOM SB PROBE\npid=%d  screen=%.0fx%.0f\nscene=%@",
                   (int)getpid(), r.size.width, r.size.height,
                   NSStringFromClass([scene.delegate class])];
    g_info.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    g_info.textColor = [UIColor colorWithWhite:0.15 alpha:1];
    g_info.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    g_info.layer.cornerRadius = 10;
    g_info.clipsToBounds = YES;
    g_info.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [g_host addSubview:g_info];

    g_win.hidden = NO;
    SBLog("installed: level=%.0f screen=%.0fx%.0f scene=%s",
          g_win.windowLevel, r.size.width, r.size.height,
          NSStringFromClass([scene.delegate class]).UTF8String);
}

__attribute__((constructor))
static void SBProbeInit(void)
{
    SBLog("======== dylib loaded into pid=%d (%s) ========", (int)getpid(),
          [[[NSProcessInfo processInfo] processName] UTF8String]);

    dispatch_async(dispatch_get_main_queue(), ^{
        SBInstall();
        // 场景变化（从锁屏/后台回来、Home 屏重建）时重建窗口
        [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification* n) {
            if (![n.object isKindOfClass:[UIWindowScene class]]) { return; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (g_win == nil) { SBInstall(); } else { g_win.hidden = NO; }
            });
        }];
    });

    // 1.5s 后补一次（scene 可能晚于 ctor 就绪）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (g_win == nil) { SBInstall(); }
    });
}
