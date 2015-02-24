#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/arch.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/swap.h>
#import <objc/runtime.h>
#import <stdio.h>

// CoreSimulator

@interface SimDeviceSet : NSObject
+ (instancetype)defaultSet;
- (NSArray *)devices;
@end

@interface SimDevice : NSObject
- (NSString *)name;
- (BOOL)supportsFeature:(NSString *)feature;
@end

// DVTFoundation

@interface DVTFilePath : NSObject
+ (instancetype)filePathForPathString:(NSString *)path;
@end

@interface DVTFuture : NSObject
- (long long)waitUntilFinished;
- (id)error;
@end

@interface DVTXPCServiceInformation : NSObject // Real superclass: DVTProcessInformation
- (instancetype)initWithServiceName:(NSString *)extensionBundleID
                                pid:(int)pid
                          parentPID:(int)parentPID;
- (void)setStartSuspended:(BOOL)flag;
- (void)setFullPath:(NSString *)path;
- (void)setEnvironment:(NSDictionary *)environment;
@end

@interface DVTPlatform : NSObject
+ (BOOL)loadAllPlatformsReturningError:(NSError **)error;
@end

@interface DVTDevice : NSObject
- (NSString *)nativeArchitecture;
- (void)terminateWatchAppForCompanionIdentifier:(NSString *)ID options:(NSDictionary *)options;
- (void)launchWatchAppForCompanionIdentifier:(NSString *)ID options:(NSDictionary *)options completionblock:(id)block;
@end

// DTXConnectionServices

@protocol XCDTMobileIS_XPCDebuggingProcotol;

@interface DTXChannel : NSObject
// Normally defined as `DTXAllowedRPC`, but because it actually has to be a protocol that itself
// conforms to `DTXAllowedRPC`. I'm defining it as `XCDTMobileIS_XPCDebuggingProcotol` which is what
// `DVTiPhoneSimulator` implements.
//
- (void)setDispatchTarget:(id <XCDTMobileIS_XPCDebuggingProcotol>)target;
@end

// IDEFoundation

// There is no option for “interface” launch mode, the key should simply be omitted completely, in
// which case it will be the default way the application is launched.
//
NSString * const kIDEWatchLaunchModeKey = @"IDEWatchLaunchMode";
NSString * const kIDEWatchLaunchModeGlance = @"IDEWatchLaunchMode-Glance";
NSString * const kIDEWatchLaunchModeNotification = @"IDEWatchLaunchMode-Notification";
NSString * const kIDEWatchNotificationPayloadKey = @"IDEWatchNotificationPayload";

// IDEiOSSupportCore

NSString * const kIDEWatchCompanionFeature = @"com.apple.watch.companion";

@interface DVTiPhoneSimulator : DVTDevice // Real superclass: DVTAbstractiOSDevice
+ (instancetype)simulatorWithDevice:(SimDevice *)device;
- (DVTFuture *)installApplicationAtPath:(DVTFilePath *)path;
- (void)debugXPCServices:(NSArray *)services;
- (DTXChannel *)xpcAttachServiceChannel;
- (SimDevice *)device;
@end

@protocol DTXAllowedRPC <NSObject>
@end

@protocol XCDTMobileIS_XPCDebuggingProcotol <DTXAllowedRPC>
- (void)outputReceived:(NSString *)output fromProcess:(int)pid atTime:(unsigned long long)time;
- (void)xpcServiceObserved:(NSString *)observedServiceID
     withProcessIdentifier:(int)pid
        requestedByProcess:(int)parentPID
                   options:(NSDictionary *)options;
@end

@class DTiPhoneSimulatorSession;

@protocol DTiPhoneSimulatorSessionDelegate
- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error;
- (void)session:(DTiPhoneSimulatorSession *)session
       didStart:(BOOL)didStart
      withError:(NSError *)error;
@end

// DVTiPhoneSimulatorRemoteClient

typedef NS_ENUM(NSInteger, DVTiPhoneSimulatorExternalDisplayType) {
  DVTiPhoneSimulatorWatchRegularExternalDisplayType = 1,
  DVTiPhoneSimulatorWatchCompactExternalDisplayType = 2,
  DVTiPhoneSimulatorCarPlayExternalDisplayType = 3
};

@interface DTiPhoneSimulatorSessionConfig : NSObject
- (void)setExternalDisplayType:(DVTiPhoneSimulatorExternalDisplayType)type;
- (void)setDevice:(SimDevice *)device;
@end

@interface DTiPhoneSimulatorSession : NSObject
- (void)setDelegate:(id <DTiPhoneSimulatorSessionDelegate>) delegate;
- (BOOL)requestStartWithConfig:(DTiPhoneSimulatorSessionConfig *)config
                       timeout:(double)timeout
                         error:(NSError **)error;
@end

// Imported classes

static Class SimDeviceSetClass = nil;
static Class SimDeviceClass = nil;
static Class DVTFilePathClass = nil;
static Class DVTXPCServiceInformationClass = nil;
static Class DVTPlatformClass = nil;
static Class DVTiPhoneSimulatorClass = nil;
static Class DTiPhoneSimulatorSessionClass = nil;
static Class DTiPhoneSimulatorSessionConfigClass = nil;
static Class DTXChannelClass = nil;

static void
InitImportedClasses(NSString *developerDir) {
  void *CoreSimulator = dlopen([[developerDir stringByAppendingPathComponent:@"Library/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"] UTF8String], RTLD_NOW);
  assert(CoreSimulator != NULL);
  SimDeviceSetClass = objc_getClass("SimDeviceSet");
  assert(SimDeviceSetClass != nil);
  SimDeviceClass = objc_getClass("SimDevice");
  assert(SimDeviceClass != nil);

  void *DVTFoundation = dlopen([[developerDir stringByAppendingPathComponent:@"../SharedFrameworks/DVTFoundation.framework/Versions/A/DVTFoundation"] UTF8String], RTLD_NOW);
  assert(DVTFoundation != NULL);
  DVTFilePathClass = objc_getClass("DVTFilePath");
  assert(DVTFilePathClass != nil);
  DVTXPCServiceInformationClass = objc_getClass("DVTXPCServiceInformation");
  assert(DVTXPCServiceInformationClass != nil);
  DVTPlatformClass = objc_getClass("DVTPlatform");
  assert(DVTPlatformClass != nil);

  void *DevToolsCore = dlopen([[developerDir stringByAppendingPathComponent:@"../OtherFrameworks/DevToolsCore.framework/DevToolsCore"] UTF8String], RTLD_NOW);
  assert(DevToolsCore != NULL);
  void *IDEiOSSupportCore = dlopen([[developerDir stringByAppendingPathComponent:@"../PlugIns/IDEiOSSupportCore.ideplugin/Contents/MacOS/IDEiOSSupportCore"] UTF8String], RTLD_NOW);
  assert(IDEiOSSupportCore != NULL);
  DVTiPhoneSimulatorClass = objc_getClass("DVTiPhoneSimulator");
  assert(DVTiPhoneSimulatorClass != nil);

  void *DTXConnectionServices = dlopen([[developerDir stringByAppendingPathComponent:@"../SharedFrameworks/DTXConnectionServices.framework/Versions/A/DTXConnectionServices"] UTF8String], RTLD_NOW);
  assert(DTXConnectionServices != NULL);
  DTXChannelClass = objc_getClass("DTXChannel");
  assert(DTXChannelClass != nil);

  void *DVTiPhoneSimulatorRemoteClient = dlopen([[developerDir stringByAppendingPathComponent:@"../SharedFrameworks/DVTiPhoneSimulatorRemoteClient.framework/Versions/A/DVTiPhoneSimulatorRemoteClient"] UTF8String], RTLD_NOW);
  assert(DVTiPhoneSimulatorRemoteClient != NULL);
  DTiPhoneSimulatorSessionConfigClass = objc_getClass("DTiPhoneSimulatorSessionConfig");
  assert(DTiPhoneSimulatorSessionConfigClass != nil);
  DTiPhoneSimulatorSessionClass = objc_getClass("DTiPhoneSimulatorSession");
  assert(DTiPhoneSimulatorSessionClass != nil);
}


// -------------------------------------------------------------------------------------------------
//
// Our Implementation
//
// -------------------------------------------------------------------------------------------------

// The channel listener class has to conform to a protocol that in turn has to conform to the
// `DTXAllowedRPC` protocol.
//
// Verification of this happens in the following order:
// * `-[DTXMessage invokeWithTarget:replyChannel:validator:]`
// * `shouldDispatchSelectorToObject`
// * `__shouldDispatchSelectorToObject_block_invoke_2`
//

@interface WatchKitLauncher : NSObject <XCDTMobileIS_XPCDebuggingProcotol, DTiPhoneSimulatorSessionDelegate>
// `launchMode` can be:
// * `nil`: the normal “interface” application is launched.
// * `kIDEWatchLaunchModeGlance`: the “glance” application is launched.
// * `kIDEWatchLaunchModeNotification`: the “notification” application is launched.
//
// `notificationPayload` should be specified if `launchMode` is `kIDEWatchLaunchModeNotification`.
//
@property (strong) NSString *launchMode;
@property (strong) NSDictionary *notificationPayload;
@property (assign) BOOL verbose;
@property (assign) BOOL startSuspended;
@property (assign) DVTiPhoneSimulatorExternalDisplayType externalDisplayType;
@end

@interface WatchKitLauncher ()
@property (readonly) NSBundle *appBundle;
@property (readonly) NSBundle *watchKitExtensionBundle;
@property (readonly) DVTiPhoneSimulator *simulator;
@property (strong) DTiPhoneSimulatorSession *session;
@end

@implementation WatchKitLauncher

@synthesize watchKitExtensionBundle = _watchKitExtensionBundle;
@synthesize simulator = _simulator;

+ (instancetype)launcherWithAppBundlePath:(NSString *)appBundlePath;
{
  return [[self alloc] initWithAppBundle:[NSBundle bundleWithPath:appBundlePath]];
}

- (instancetype)initWithAppBundle:(NSBundle *)appBundle;
{
  NSParameterAssert(appBundle);
  if ((self = [super init])) {
    _appBundle = appBundle;
    _externalDisplayType = DVTiPhoneSimulatorWatchRegularExternalDisplayType;
  }
  return self;
}

// Launch flow is as follows:
// * ensure simulator is running and with correct device
// * install application
// * actually launch application
// * attach debugger
//
- (void)launch;
{
  if (self.verbose) {
    printf("-> Launching simulator with device `%s`...\n", [self.simulator.device.name UTF8String]);
  }

  NSError *error = nil;
  if (![DVTPlatformClass loadAllPlatformsReturningError:&error]) {
    fprintf(stderr, "[!] Unable to initialize Dev Tools (%s).\n", [[error description] UTF8String]);
    exit(1);
  }

  DTiPhoneSimulatorSessionConfig *config = [DTiPhoneSimulatorSessionConfigClass new];
  config.device = self.simulator.device;
  config.externalDisplayType = self.externalDisplayType;
  self.session = [DTiPhoneSimulatorSessionClass new];
  self.session.delegate = self;
  if (![self.session requestStartWithConfig:config timeout:0 error:&error]) {
    fprintf(stderr, "[!] Unable to launch the Simulator (%s).\n", [[error description] UTF8String]);
    exit(1);
  }
}

// Called from `session:didStart:withError:` once the simulator is running.
//
- (void)continueLaunch;
{
  [self installApplication];
  [self actuallyLaunch];
}

// Install the application to the `device`. This could be done in any number of ways, including the
// newly available `simctl` tool. But for now this tool replicates the behaviour seen in Xcode when
// launching extensions.
//
- (void)installApplication;
{
  if (self.verbose) {
    printf("-> Installing `%s`...\n", [self.appBundle.bundlePath UTF8String]);
  }
  DVTFilePath *appFilePath = [DVTFilePathClass filePathForPathString:self.appBundle.bundlePath];
  DVTFuture *installation = [self.simulator installApplicationAtPath:appFilePath];
  [installation waitUntilFinished];
  if (installation.error != nil) {
    fprintf(stderr, "[!] An error occurred while installing the application (%s)\n",
                    [[installation.error description] UTF8String]);
    exit(1);
  }
}

- (void)actuallyLaunch;
{
  if (self.verbose) {
    printf("-> Launching application...\n");
  }

  DVTXPCServiceInformation *unstartedService = [self watchKitAppInformation];
  [self.simulator debugXPCServices:@[unstartedService]];
  DTXChannel *channel = self.simulator.xpcAttachServiceChannel;
  channel.dispatchTarget = self;

  NSString *appBundleID = self.appBundle.bundleIdentifier;
  // Reap any existing process
  [self.simulator terminateWatchAppForCompanionIdentifier:appBundleID options:@{}];
  // Start new process
  [self.simulator launchWatchAppForCompanionIdentifier:appBundleID options:self.launchOptions completionblock:^(id error) {
    if (error != nil) {
      fprintf(stderr, "[!] An error occurred while launching the application (%s)\n",
                      [[error description] UTF8String]);
      exit(1);
    }
  }];
}

- (void)attachDebuggerToPID:(int)pid;
{
  NSString *commands = [NSString stringWithFormat:@"" \
                         "process attach -p %d\n" \
                         "breakpoint set --name objc_exception_throw\n", pid];
  if (!self.startSuspended) {
    commands = [commands stringByAppendingString:@"continue\n"];
  }
  char path[PATH_MAX];
  snprintf(path, PATH_MAX, "%s/watch-sim-debugger-commands.XXXXXX", (getenv("TMPDIR") ?: "/tmp"));
  assert(mktemp(path) != NULL);
  NSError *error = nil;
  if (![commands writeToFile:[NSString stringWithUTF8String:path]
                  atomically:YES
                    encoding:NSASCIIStringEncoding
                       error:&error]) {
    fprintf(stderr, "[!] Unable to save debugger commands file to `%s` (%s)\n", path,
                    [[error description] UTF8String]);
    exit(1);
  }

  if (self.verbose) {
    printf("-> Attaching debugger...\n");
  }
  char command[1024];
  sprintf(command, "lldb -s %s", path);
  int status = system(command);

  if (self.verbose) {
    printf("-> Exiting...\n");
  }

  // Reap process.
  // TODO exiting immediately afterwards makes reaping not actually work.
  NSString *appBundleID = self.appBundle.bundleIdentifier;
  [self.simulator terminateWatchAppForCompanionIdentifier:appBundleID options:@{}];

  // Exit launcher with status from LLDB.
  // TODO Is that helpful?
  exit(status);
}

#pragma mark - Accessors

- (NSBundle *)watchKitExtensionBundle;
{
  @synchronized(self) {
    if (_watchKitExtensionBundle == nil) {
      NSString *pluginsPath = self.appBundle.builtInPlugInsPath;
      NSError *error = nil;
      NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath
                                                                             error:&error];
      if (error) {
        fprintf(stderr, "[!] Unable to read host application’s PlugIns directory (%s).\n",
                        [[error description] UTF8String]);
        exit(1);
      }
      for (NSString *plugin in plugins) {
        if ([[plugin pathExtension] isEqualToString:@"appex"]) {
          NSString *extensionPath = [pluginsPath stringByAppendingPathComponent:plugin];
          NSBundle *extensionBundle = [NSBundle bundleWithPath:extensionPath];
          NSDictionary *extensionInfo = extensionBundle.infoDictionary;
          NSString *extensionType = extensionInfo[@"NSExtension"][@"NSExtensionPointIdentifier"];
          if ([extensionType isEqualToString:@"com.apple.watchkit"]) {
            _watchKitExtensionBundle = extensionBundle;
            break;
          }
        }
      }
      assert(_watchKitExtensionBundle != nil);
    }
  }
  return _watchKitExtensionBundle;
}

- (DVTiPhoneSimulator *)simulator;
{
  @synchronized(self) {
    if (_simulator == nil) {
      DVTiPhoneSimulator *simulator = nil;
      NSArray *architectures = [self watchKitAppArchitectures];
      for (SimDevice *availableDevice in [[SimDeviceSetClass defaultSet] devices]) {
        simulator = [DVTiPhoneSimulatorClass simulatorWithDevice:availableDevice];
        if ([availableDevice supportsFeature:kIDEWatchCompanionFeature]
            && [architectures indexOfObject:simulator.nativeArchitecture] != NSNotFound) {
          _simulator = simulator;
          break;
        }
      }
      if (_simulator == nil) {
        fprintf(stderr, "[!] Cannot find any simulator devices, please add devices in " \
                        "Xcode -> Window -> Devices.\n");
        exit(1);
      }
    }
  }
  return _simulator;
}

static NSString *
NameOfArchitecture(cpu_type_t cputype, cpu_subtype_t cpusubtype) {
  const NXArchInfo *arch_info = NXGetArchInfoFromCpuType(cputype, cpusubtype);
  return [NSString stringWithUTF8String:arch_info->name];
}

- (NSArray *)watchKitAppArchitectures;
{
  FILE *executable = fopen([self.watchKitExtensionBundle.executablePath UTF8String], "rb");
  if (executable == NULL) {
    fprintf(stderr, "[!] Unable to open WatchKit executable (%s).\n", strerror(errno));
    exit(1);
  }

  // Get at least size of a fat_header and two fat_arch structs (sim only has i386 and x86_64,
  // because it's larger than a single mach_header, so we can safely fall back.
  size_t buffer_size = sizeof(struct fat_header) + (sizeof(struct fat_arch) * 2);
  uint8_t bytes[buffer_size];
  size_t read_bytes = fread((void *)bytes, buffer_size, 1, executable);
  fclose(executable);
  if (read_bytes == 0) {
    fprintf(stderr, "[!] Unable to read WatchKit executable (%s).\n", strerror(errno));
    exit(1);
  }

  NSMutableArray *architectures = [NSMutableArray new];
  struct fat_header fheader = *(struct fat_header *)bytes;
  if (fheader.magic == FAT_MAGIC || fheader.magic == FAT_CIGAM) {
    if (fheader.magic == FAT_CIGAM) {
      swap_fat_header(&fheader, NX_LittleEndian);
    }
    struct fat_arch *archs = (struct fat_arch *)((struct fat_header *)bytes+1);
    for (uint32_t i = 0; i < fheader.nfat_arch; i++) {
      struct fat_arch arch = archs[i];
      swap_fat_arch(&arch, 1, NX_LittleEndian);
      [architectures addObject:NameOfArchitecture(arch.cputype, arch.cpusubtype)];
    }
  } else {
    struct mach_header mheader = *(struct mach_header *)bytes;
    [architectures addObject:NameOfArchitecture(mheader.cputype, mheader.cpusubtype)];
  }

  assert(architectures.count > 0);
  if (self.verbose) {
    printf("-> Detected architecture(s) of WatchKit executable to be: %s\n",
           [[architectures componentsJoinedByString:@", "] UTF8String]);
  }
  return [architectures copy];
}

// TODO Do we maybe need to set all those build paths in the env for dSYM location, or is it just in
// case a framework is loaded and is not inside the host app bundle?
//
- (DVTXPCServiceInformation *)watchKitAppInformation;
{
  NSString *name = self.watchKitExtensionBundle.bundleIdentifier;
  DVTXPCServiceInformation *app = [[DVTXPCServiceInformationClass alloc] initWithServiceName:name
                                                                                         pid:-1
                                                                                   parentPID:0];
  app.fullPath = self.watchKitExtensionBundle.bundlePath;
  app.startSuspended = YES;
  app.environment = @{ @"NSUnbufferedIO": @"YES" };
  //app.environment = @{
    //@"NSUnbufferedIO": @"YES",
    //@"DYLD_FRAMEWORK_PATH": buildDir,
    //@"DYLD_LIBRARY_PATH": buildDir,
    //@"__XCODE_BUILT_PRODUCTS_DIR_PATHS": buildDir,
    //@"__XPC_DYLD_FRAMEWORK_PATH": buildDir,
    //@"__XPC_DYLD_LIBRARY_PATH": buildDir
  //};
  return app;
}

- (NSDictionary *)launchOptions;
{
  NSMutableDictionary *options = [NSMutableDictionary new];
  if (self.launchMode) {
    options[kIDEWatchLaunchModeKey] = self.launchMode;
    if ([self.launchMode isEqualToString:kIDEWatchLaunchModeNotification]) {
      NSParameterAssert(self.notificationPayload);
      options[kIDEWatchNotificationPayloadKey] = self.notificationPayload;
    }
  }
  return [options copy];
}

#pragma mark - DTiPhoneSimulatorSessionDelegate

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error;
{
  if (error != nil) {
    fprintf(stderr, "[!] Ended Simulator session (%s).\n", [[error description] UTF8String]);
    exit(1);
  }
}

- (void)session:(DTiPhoneSimulatorSession *)session
       didStart:(BOOL)didStart
      withError:(NSError *)error;
{
  if (!didStart) {
    fprintf(stderr, "[!] Unable to launch the Simulator (%s).\n", [[error description] UTF8String]);
    exit(1);
  }
  [self continueLaunch];
}

#pragma mark - XCDTMobileIS_XPCDebuggingProcotol

// If our service has started, connect to it with LLDB from the main thread. Do not block the XPC
// queue any further, otherwise we won't get any output messages.
//
- (void)xpcServiceObserved:(NSString *)observedServiceID
     withProcessIdentifier:(int)pid
        requestedByProcess:(int)parentPID
                   options:(NSDictionary *)options;
{
  if ([observedServiceID isEqualToString:self.watchKitExtensionBundle.bundleIdentifier]) {
    if (self.verbose) {
      printf("-> Requested XPC service has been observed with PID: %d\n", pid);
    }
    assert(pid > 0);
    dispatch_async(dispatch_get_main_queue(), ^{
      [self attachDebuggerToPID:pid];
    });
  }
}

// Directly print from the XPC queue this is delivered on so that it's shown while LLDB is running.
//
- (void)outputReceived:(NSString *)output fromProcess:(int)pid atTime:(unsigned long long)time;
{
  printf("%s", [output UTF8String]);
}

@end

void
print_help_banner(void) {
  fprintf(stderr, "Usage: watch-sim path/to/build/WatchHost.app -display [Compact|Regular] " \
                  "-type [Glance|Notification] -notification-payload [path/to/payload.json] " \
                  "-verbose [YES|NO] -start-suspended [YES|NO] " \
                  "-developer-dir [Xcode.app/Contents/Developer]\n");
}

int
main(int argc, char **argv) {
  NSArray *allArguments = [NSProcessInfo processInfo].arguments;
  NSMutableArray *arguments = [NSMutableArray new];
  for (NSInteger i = 1; i < argc; i++) {
    NSString *argument = allArguments[i];
    if ([argument hasPrefix:@"-"]) {
      // Skip next argument, which is the value for this option.
      i++;
    } else {
      [arguments addObject:argument];
    }
  }

  if (arguments.count != 1) {
    print_help_banner();
    return 1;
  }
  NSString *appPath = arguments[0];

  NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
  BOOL verbose = [options boolForKey:@"verbose"];
  BOOL startSuspended = [options boolForKey:@"start-suspended"];

  DVTiPhoneSimulatorExternalDisplayType externalDisplayType = 0;
  NSString *displayType = [[options valueForKey:@"display"] lowercaseString];
  if (displayType != nil) {
    if ([displayType isEqualToString:@"regular"]) {
      externalDisplayType = DVTiPhoneSimulatorWatchRegularExternalDisplayType;
    } else if ([displayType isEqualToString:@"compact"]) {
      externalDisplayType = DVTiPhoneSimulatorWatchCompactExternalDisplayType;
    } else {
      fprintf(stderr, "[!] Unknown external display type `%s`.\n", [displayType UTF8String]);
      print_help_banner();
      return 1;
    }
  }

  NSString *launchMode = nil;
  NSDictionary *notificationPayload = nil;
  NSString *appType = [[options valueForKey:@"type"] lowercaseString];
  if (appType != nil) {
    if ([appType isEqualToString:@"glance"]) {
      launchMode = kIDEWatchLaunchModeGlance;
    } else if ([appType isEqualToString:@"notification"]) {
      // Get the obligatory notification payload (JSON) data.
      launchMode = kIDEWatchLaunchModeNotification;
      NSString *payloadFile = [options valueForKey:@"notification-payload"];
      if (payloadFile == nil) {
        fprintf(stderr, "[!] A `-notification-payload` is required with `-type Notification`.\n");
        print_help_banner();
        return 1;
      }
      NSData *payloadData = [NSData dataWithContentsOfFile:payloadFile];
      NSError *error = nil;
      notificationPayload = [NSJSONSerialization JSONObjectWithData:payloadData
                                                            options:0
                                                              error:&error];
      if (error != nil) {
        fprintf(stderr, "[!] Unable to load notification payload file `%s` (%s)\n",
                        [payloadFile UTF8String], [[error description] UTF8String]);
        return 1;
      }
      assert([notificationPayload isKindOfClass:[NSDictionary class]]);
    } else {
      fprintf(stderr, "[!] Unknown application type `%s`.\n", [appType UTF8String]);
      print_help_banner();
      return 1;
    }
  }

  NSString *developerDir = [options valueForKey:@"developer-dir"];
  if (developerDir == nil) {
    char *dir = getenv("DEVELOPER_DIR");
    if (dir == NULL) {
      FILE *pipe = popen("/usr/bin/xcode-select -p", "r");
      assert(pipe != NULL);
      char buffer[PATH_MAX];
      assert(fgets(buffer, PATH_MAX, pipe) != NULL);
      pclose(pipe);
      dir = buffer;
    }
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    developerDir = [[NSString stringWithUTF8String:dir] stringByTrimmingCharactersInSet:whitespace];
  }

  InitImportedClasses(developerDir);

  WatchKitLauncher *launcher = [WatchKitLauncher launcherWithAppBundlePath:appPath];
  launcher.verbose = verbose;
  launcher.startSuspended = startSuspended;
  launcher.launchMode = launchMode;
  launcher.notificationPayload = notificationPayload;
  if (externalDisplayType != 0) {
    launcher.externalDisplayType = externalDisplayType;
  }
  [launcher launch];

  while (1) {
    CFRunLoopRun();
  }

  // This should never be reached.
  return 1;
}
