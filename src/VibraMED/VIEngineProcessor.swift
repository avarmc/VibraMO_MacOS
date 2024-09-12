//
//  VIEngine.swift
//  VibraMED
//
//  Created by Elsys Corp. on 07.12.2020.
//

import UIKit
import AVFoundation
import Foundation
import VIEngineLib

class VIEngineProcessor : VIEngineLibClx {
    private var base:CameraViewController!

    private var imgDrawPtr:UnsafeMutablePointer<UInt32>!
    private var imgDrawPtrSize:Int = 0
    
    public var viOrientation:Int32 = 1
    
    
    init(_ base:CameraViewController) {
        super.init()
        self.base = base
        
                
        // set default view mode
        _ = regLoadI("VI_MODE_RESULT", def: self.jni.tag2Id("VI_RESULT_SRC_0"))
        _ = regLoadI("VI_MODE_AURA", def: self.jni.tag2Id("VI_RESULT_VI0_B"))
        
        
        // enable face detection
        self.jni.enginePutIt("VI_FACE_ENABLE", and_v: 1 );
        
        // VI_MODE_FACE_DRAW_DISABLED or VI_MODE_FACE_DRAW_ALL or VI_MODE_FACE_DRAW_YES
        self.jni.enginePutIt("VI_FACE_DRAW", and_v: self.jni.tag2Id("VI_MODE_FACE_DRAW_DISABLED") );


        //   self.jni.enginePutStrt("VI_VAR_AI_PATH", and_v:  path )
        if let neuro_data = NSDataAsset(name: "neuro") {
            let str = String(data: neuro_data.data, encoding: .utf8)!
            self.jni.enginePutStrt("VI_VAR_AI_DATA", and_v:  str )
        }
  //      self.jni.enginePutFt("VI_INFO_M_PERIOD",and_v: 60.0)
  //      self.jni.enginePutFt("VI_INFO_M_DELAY",and_v: 10.0)
    }
    
    
    
    private func regLoadI(_ sid:String, def:Int32) -> Bool {
        let prev = UserDefaults.standard.string(forKey: sid )
        if prev == nil {
            self.jni.enginePutIt("VI_MODE_RESULT",and_v: def )
            return false
        }
        let iv = Int32(prev!)!
        self.jni.enginePutIt(sid,and_v: iv )
        return true
    }
    
    private func regSaveI(_ sid:String) {
        UserDefaults.standard.set(self.jni.engineGetIt(sid), forKey: sid)
    }
    
    public func addImage(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)


        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
      
        let size = height * lumaBytesPerRow

        let int8Pointer: UnsafeMutablePointer<UInt8> = (lumaBaseAddress?.bindMemory(to: UInt8.self,
                                                                                   capacity: size))!

        self.viOrientation = getOrientation()
        
        self.jni.engineAddImage(int8Pointer, and_size: Int32(size), and_w: Int32(width), and_h: Int32(height), and_stride: Int32(lumaBytesPerRow), and_deviceRotation: self.viOrientation)
        
        peekImage()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer,CVPixelBufferLockFlags(rawValue: 0))
    }
    
    override public func onCheckResult(_ str:String) {
        if( str == "zip ready") {
            let zip = jni.engineGetZipResult() 
            self.onZipResult(zip)
        }
        self.base.onCheckResult(str)
    }
    
    
    
    public func nextPreset() {
        let np = (getPreset()+1) % 4
        setPreset( np )
    }
    
    public func setPreset(_ preset: Int ) {
        switch(preset) {

        case 0: //VI
            self.jni.enginePutIt("VI_MODE_RESULT",and_v: self.jni.tag2Id("VI_RESULT_VI0_B"))
            self.jni.enginePutIt("VI_MODE_AURA",and_v: 0)
            break;
        case 1: //AV
            self.jni.enginePutIt("VI_MODE_RESULT",and_v: self.jni.tag2Id("VI_RESULT_VI0_B"))
            self.jni.enginePutIt("VI_MODE_AURA",and_v: self.jni.tag2Id("VI_RESULT_VI0_B"))
            break;
        case 2: //AR
            self.jni.enginePutIt("VI_MODE_RESULT",and_v: self.jni.tag2Id("VI_RESULT_SRC_0"))
            self.jni.enginePutIt("VI_MODE_AURA",and_v: self.jni.tag2Id("VI_RESULT_SRC_0"))
            break;
        case 3: //LD
            self.jni.enginePutIt("VI_MODE_RESULT",and_v: self.jni.tag2Id("VI_RESULT_SRC_0"))
            self.jni.enginePutIt("VI_MODE_AURA",and_v: 0)
            break;
        default:
            break
        }
        
        regSaveI("VI_MODE_RESULT")
        regSaveI("VI_MODE_AURA")
        UserDefaults.standard.synchronize()
    }
    
    public func getPreset() -> Int {
        let modeR = self.jni.engineGetIt("VI_MODE_RESULT")
        let modeA = self.jni.engineGetIt("VI_MODE_AURA")
        
        if( (modeR & jni.tag2Id("VI_RESULT_VI0_B")) != 0 ) {
            if( (modeA & jni.tag2Id("VI_RESULT_VI0_B")) != 0 ) {
                return 1;
            }
            return 0;
        }

        if( (modeA & jni.tag2Id("VI_RESULT_SRC_0")) != 0 ) {
            return 2;
        }

        return 3
    }
    
    private func getOrientation() -> Int32{
        var face:Int32 = -1
        let position = self.base.videoDevicePosition
        if(position == .front) {
            face = 1
        }
        
        switch UIDevice.current.orientation {
        case .portrait:
            return jni.tag2Id("ROTATION_0")*face
        case .portraitUpsideDown:
            return jni.tag2Id("ROTATION_180")*face
        case .landscapeRight:
            return jni.tag2Id("ROTATION_90")*face
        case .landscapeLeft:
            return jni.tag2Id("ROTATION_270")*face
        case .unknown:
            break
        case .faceUp:
            return jni.tag2Id("ROTATION_0")*face
        case .faceDown:
            return jni.tag2Id("ROTATION_0")*face
        @unknown default:
            break
        }
            
        return jni.tag2Id("ROTATION_0")*face
    }
    
    private func peekImage() {
        let w = Int(self.jni.engineGetIt("VI_VAR_SIZE_W"))
        let h = Int(self.jni.engineGetIt("VI_VAR_SIZE_H"))
        let viOrientation = getOrientation()
        let wh = w*h
        
        if(self.imgDrawPtr == nil || self.imgDrawPtrSize != wh ) {
            self.imgDrawPtrSize = Int(wh)
            self.imgDrawPtr = UnsafeMutablePointer<UInt32>.allocate(capacity: self.imgDrawPtrSize )
        }
        
        let modeR = self.jni.engineGetIt("VI_MODE_RESULT")
        let modeA = self.jni.engineGetIt("VI_MODE_AURA")

        
        self.jni.engineDrawResult(modeR, and_aura: modeA, and_bmp: self.imgDrawPtr,and_w: Int32(w),and_h: Int32(h),and_stride: Int32(w*4))
        

        
        self.base.engineView!.setImage(pixels: self.imgDrawPtr,width: w,height: h, viOrientation: Int(viOrientation))

    }
    
    
    private func onZipResult(_ zip:Data) {
        var url:String = self.base.httpHelper.urlMeasure()
    
        let zurl = self.jni.engineGetStrt("VI_INFO_ZIP_URL")

        let zip64 = zip.base64EncodedData()
        
        url += "&" + zurl.suffix(zurl.count-1)
        

        var zip64s:String = String(decoding:zip64,as: UTF8.self)

        if let _ = zip64s.firstIndex(of: "/") {
            zip64s = zip64s.replacingOccurrences(of: "/", with: "_")
        }
        if let _ = zip64s.firstIndex(of: "+") {
            zip64s = zip64s.replacingOccurrences(of: "+", with: "-")
        }
        
        var postData = "zip_size=" + String(zip.count)
        postData += "&zip64_size=" + String(zip64.count)
        postData += "&zip="+zip64s
        postData += "&end=*"
        self.base.httpHelper.navigatePost(url, withData: postData)
    }

    
    public func localizedString(forKey key: String) -> String {
        var result = Bundle.main.localizedString(forKey: key, value: nil, table: nil)

        if result == key {
            result = Bundle.main.localizedString(forKey: key, value: nil, table: "Default")
        }

        return result
    }
    
    


}

