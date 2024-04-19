//
//  CameraView.swift
//  TakeItEasy
//
//  Created by 马浩萌 on 2024/4/16.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    var callback: (() -> Void)?
    @Binding var txt: String /// 也可以通过@Binding改变时会调用updateUIViewController(_:context:)来执行特定的函数(@Binding实现事件传递)

    private let cameraViewController = CameraViewController()

    func makeUIViewController(context: Context) -> CameraViewController {
        return cameraViewController
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        print(txt)
    }
    
    func testAction() {
        print(#function)
        callback?()
    }
}

class CameraViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private let cameraBufferQueue = DispatchQueue(label: "com.mahaomeng.camera_buffer_queue")
    
    private var renderView: RenderView?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        preprareRenderView()
        
        prepareCamera()
    }
    
    func prepareCamera() {
        guard let frontCaptureDevice =
                AVCaptureDevice.DiscoverySession.init(deviceTypes: [
                    .builtInDualCamera,
                    .builtInTripleCamera,
                    .builtInTelephotoCamera,
                    .builtInDualWideCamera,
                    .builtInWideAngleCamera
                ], mediaType: .video, position: .front).devices.first else {
            print("@mahaomeng/error frontCaptureDevice is null")
            return
        }
        
        // 设置帧率
        do {
            try frontCaptureDevice.lockForConfiguration()
            frontCaptureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30/*fps*/)
            frontCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30/*fps*/)
            frontCaptureDevice.unlockForConfiguration()
        } catch {
            print("@mahaomeng/error \(error)")
        }
        
        do {
            // 设置输入设备（前/后摄像头）
            let captureInput = try AVCaptureDeviceInput(device: frontCaptureDevice)
            if captureSession.canAddInput(captureInput) {
                captureSession.addInput(captureInput)
            }
            
            let captureVideoDataOutput = AVCaptureVideoDataOutput()
            captureVideoDataOutput.alwaysDiscardsLateVideoFrames = true
            // 设置视频帧buffer格式
            // YUV  -   kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            // BGRA -   kCVPixelFormatType_32BGRA
            let videoSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            captureVideoDataOutput.videoSettings = videoSettings
            
            captureVideoDataOutput.setSampleBufferDelegate(self, queue: cameraBufferQueue)
            if captureSession.canAddOutput(captureVideoDataOutput) {
                captureSession.addOutput(captureVideoDataOutput)
            }
            
            if let connection = captureVideoDataOutput.connection(with: .video) {
                // 设置buffer的方向 （如果不设置默认为.landscapeLeft，即90°）
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                
                // 设置buffer mirror
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            
            captureSession.beginConfiguration()
            // 设置分辨率
            let resolution: AVCaptureSession.Preset = .vga640x480
            if captureSession.canSetSessionPreset(resolution) {
                captureSession.sessionPreset = resolution
            }
            captureSession.commitConfiguration()
            
            captureSession.startRunning()
        } catch {
            print("@mahaomeng/error \(error)")
        }
    }
    
    private func preprareRenderView() {
        renderView = RenderView(frame: view.frame)
        guard let renderView = renderView else { return }
        view = renderView
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        self.renderView?.glDraw(pixelBuffer: pixelBuffer)
    }
}
