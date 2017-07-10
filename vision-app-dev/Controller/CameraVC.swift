//
//  ViewController.swift
//  vision-app-dev
//
//  Created by Caleb Stultz on 7/6/17.
//  Copyright © 2017 Caleb Stultz. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import CoreML

enum FlashState {
    case off
    case on
}

class CameraVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
    
    var captureSession: AVCaptureSession?
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var model = SqueezeNet()
    
    var flashControlState: FlashState = .off
    
    let speechSynthesizer = AVSpeechSynthesizer()
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var captureImageView: RoundedShadowImageView!
    @IBOutlet weak var flashControlBtn: UIButton!
    @IBOutlet weak var textLbl: UILabel!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = cameraView.bounds
        speechSynthesizer.delegate = self
        spinner.isHidden = true
    }
    
    override  func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView(sender:)))
        tap.numberOfTapsRequired = 1
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
                
                cameraOutput = AVCapturePhotoOutput()
                
                if captureSession?.canAddOutput(cameraOutput!) == true {
                    captureSession?.addOutput(cameraOutput!)
                    
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                    previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                    
                    cameraView.layer.addSublayer(previewLayer!)
                    cameraView.addGestureRecognizer(tap)
                    captureSession?.startRunning()
                }
            }
        } catch {
            print(error)
        }
    }
    
    @objc func didTapCameraView(sender: UITapGestureRecognizer) {
        self.cameraView.isUserInteractionEnabled = false
        
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType, kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 160]
        
        settings.previewPhotoFormat = previewFormat
        
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let error = error {
            print("Oops! An error occured: \(error.localizedDescription)")
        } else {
            let photoSampleBuffer = photoSampleBuffer
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer!, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: myResultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try? handler.perform([request])
            } catch {
                print(error)
            }
            
            let image = UIImage(data: photoData!)
            self.captureImageView.image = image!
            
            self.spinner.isHidden = false
            self.spinner.startAnimating()
        }
    }
    
    func myResultsMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation]
            else { fatalError("There was an error") }
        
        for classification in results {
            if classification.confidence < 0.4 {
                self.textLbl.text = "I'm not sure what this is.\n Please try again."
                synthesizeSpeech(fromString: "I'm not sure what this is. Please try again.")
                self.confidenceLbl.text = ""
                break
            } else {
                self.textLbl.text = classification.identifier
                synthesizeSpeech(fromString: "This looks like a \(classification.identifier) and I'm \(Int(classification.confidence * 100)) percent sure.")
                self.confidenceLbl.text = "CONFIDENCE: \(Int(classification.confidence * 100))%"
                break
            }
        }
    }
    
    func synthesizeSpeech(fromString string: String) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterance)
    }
    
    @IBAction func flashControlBtnWasPressed(_ sender: Any) {
        switch flashControlState {
        case .off:
            flashControlBtn.setTitle("Flash On", for: .normal)
            flashControlState = .on
        case .on:
            flashControlBtn.setTitle("Flash Off", for: .normal)
            flashControlState = .off
        }
    }
}

extension CameraVC: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            self.cameraView.isUserInteractionEnabled = true
        self.spinner.isHidden = true
        self.spinner.stopAnimating()
    }
}
