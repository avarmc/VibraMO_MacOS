//
//  VIEngineWrapper.h
//  VIEngineLib
//
//  Created by Valeriy Akimov on 02.12.2020.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface VIEngineWrapper : NSObject
- (instancetype)init;
// - (int)test;
- (int)startEngine:(int) nCores;
- (int)stopEngine;
- (float)  EngineAddImage:(Byte*)data and_size:(int)size and_w:(int)w  and_h:(int)h  and_stride:(int)stride  and_deviceRotation:(int)deviceRotation;
- (float)  EngineAddImage32: (int*) data and_size:(int)size and_w:(int)w and_h:(int)h and_stride:(int) stride and_deviceRotation:(int) deviceRotation;
- (int)   EngineSetFace: (int) x and_y:(int)y and_w:(int) w and_h:(int) h;
- (int)   EngineGetType:(int)id;

- (int)   EngineGetVer:(int) id;
- (int)   EngineGetVert:(NSString*) tag;
- (int)   EngineGetI:(int) id;
- (float)  EngineGetF:(int) id;
- (int)   EngineGetIt:(NSString*) tag;
- (float)  EngineGetFt:(NSString*) tag;
- (int)   EnginePutI:(int) id and_v:(int) v;
- (int)   EnginePutF:(int) id and_v:(float) v;
- (int)   EnginePutIt:(NSString*) tag and_v:(int) v;
- (int)   EnginePutFt:(NSString*) tag and_v:(float) v;
- (int)   EnginePutStr:(int) id and_v:(NSString*) v;
- (NSString*) EngineGetStr:(int) id;
- (int)   EnginePutStrt:(NSString*) tag and_v:(NSString*) v;
- (NSString*) EngineGetStrt:(NSString*) tag;
- (int)   Tag2Id:(NSString*) tag;
- (NSString*) Id2Tag:(int) id;
- (int)   isStarted;
- (int)   EngineDrawResult:(int) mode and_aura:(int) aura  and_bmp:(unsigned int*) bmp and_w:(int)w and_h:(int)h and_stride:(int)stride;
- (int)   measureStop;
- (int)   measureAbort;
- (int)   measureStart;
- (NSString*)   EngineCheck;
- (int)   SetDataDir:(NSString*) dirRoot and_dirDB:(NSString*) dirDB;
- (int)   PutLang:(NSString*) tag and_v:(NSString*) v;
- (int)   SkipSet:(int) v;
- (int)   Defaults:(int) mode;
- (NSData *) EngineGetZipResult;
- (NSString*) EngineGetLoginUrl;
- (int)   EngineCheckLogin:(NSString*) answer;

- (void)dealloc;
@end

NS_ASSUME_NONNULL_END
