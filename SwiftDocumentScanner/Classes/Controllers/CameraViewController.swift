//
//  CameraViewController.swift
//  DocumentScanner
//
//  Created by Jonas Beckers on 25/02/18.
//

import AVFoundation
import Foundation
import UIKit

public protocol CameraViewControllerDelegate: class {

	func cameraViewController(didFocus point: CGPoint)
	func cameraViewController(update status: AVAuthorizationStatus)
	func cameraViewController(captured image: UIImage)

}

@available(iOS 10.0, *)
open class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

	public var fixedOrientation: AVCaptureVideoOrientation?
	public var videoOrientation: AVCaptureVideoOrientation = .portrait {
		didSet {
			guard let orientation = fixedOrientation else {
				previewLayer?.connection?.videoOrientation = videoOrientation
				return
			}
			previewLayer?.connection?.videoOrientation = orientation
		}
	}
	public var preset: AVCaptureSession.Preset = .high {
		didSet { reconfigureSession() }
	}
	public var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
		didSet { previewLayer?.videoGravity = videoGravity }
	}
	public var lowLightBoost: Bool = false {
		didSet { reconfigureSession() }
	}

	public var tapToFocus: Bool = false
	public var flashMode: AVCaptureDevice.FlashMode = .off

	public var cameraPosition: AVCaptureDevice.Position = .back {
		didSet { reconfigureSession() }
	}

	private(set) var session: AVCaptureSession = AVCaptureSession()
	private(set) var previewLayer: AVCaptureVideoPreviewLayer?

	private var captureDevice: AVCaptureDevice?
	private var captureDeviceInput: AVCaptureDeviceInput?
	private var capturePhotoOutput: AVCapturePhotoOutput?
	private var captureVideoOutput: AVCaptureVideoDataOutput?

	public weak var cameraDelegate: CameraViewControllerDelegate?

	open override func viewDidLoad() {
		super.viewDidLoad()

		let previewLayer = AVCaptureVideoPreviewLayer(session: session)
		previewLayer.videoGravity = videoGravity
		view.layer.insertSublayer(previewLayer, at: 0)
		self.previewLayer = previewLayer

		let status = AVCaptureDevice.authorizationStatus(for: .video)
		switch status {
		case .authorized:
			configureSession()
			cameraDelegate?.cameraViewController(update: status)
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
				let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
				if granted {
					self.configureSession()
				}
				self.cameraDelegate?.cameraViewController(update: newStatus)
			}
		default:
			cameraDelegate?.cameraViewController(update: status)
		}

		videoOrientation = currentOrientation()
	}

	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		guard session.isRunning else { return }
		session.stopRunning()
	}

	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		guard !session.isRunning else { return }
		session.startRunning()
	}

	open override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		previewLayer?.frame = view.bounds
		previewLayer?.videoGravity = videoGravity
		previewLayer?.connection?.videoOrientation = videoOrientation
	}

	open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		forceOrientation()
	}

	public func takePhoto() {
		guard let output = capturePhotoOutput, session.isRunning else { return }

		let settings = AVCapturePhotoSettings()
		settings.flashMode = flashMode
		settings.isHighResolutionPhotoEnabled = true
		settings.isAutoStillImageStabilizationEnabled = true

		let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first ?? 0
		let previewFormat = [
			kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
			kCVPixelBufferWidthKey as String: 160,
			kCVPixelBufferHeightKey as String: 160
		]

		settings.previewPhotoFormat = previewFormat

		output.capturePhoto(with: settings, delegate: self)
	}

	open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard tapToFocus, let touch = touches.first else { return }

		let location = touch.preciseLocation(in: view)
		let size = view.bounds.size
		let focusPoint = CGPoint(x: location.x / size.height, y: 1 - location.x / size.width)

		guard let captureDevice = captureDevice else { return }
		do {
			try captureDevice.lockForConfiguration()
			if captureDevice.isFocusPointOfInterestSupported {
				captureDevice.focusPointOfInterest = focusPoint
				captureDevice.focusMode = .autoFocus
			}
			if captureDevice.isExposurePointOfInterestSupported {
				captureDevice.exposurePointOfInterest = focusPoint
				captureDevice.exposureMode = .continuousAutoExposure
			}
			captureDevice.unlockForConfiguration()
			cameraDelegate?.cameraViewController(didFocus: location)
		} catch {
			print(error)
		}
	}

	public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
	}

	public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
	}

	// MARK: - Private

	private func forceOrientation() {
		switch UIApplication.shared.statusBarOrientation {
		case .portrait:
			videoOrientation = .portrait
		case .landscapeLeft:
			videoOrientation = .landscapeRight
		case .landscapeRight:
			videoOrientation = .landscapeLeft
		case .portraitUpsideDown:
			videoOrientation = .portraitUpsideDown
		case .unknown:
			videoOrientation = currentOrientation()
		}
	}

	private func currentOrientation() -> AVCaptureVideoOrientation {
		switch UIApplication.shared.statusBarOrientation {
		case .portrait:
			return .portrait
		case .landscapeLeft:
			return .landscapeLeft
		case .landscapeRight:
			return .landscapeRight
		case .portraitUpsideDown:
			return .portraitUpsideDown
		case .unknown:

			switch UIDevice.current.orientation {
			case .landscapeLeft:
				return .landscapeRight
			case .portrait:
				return .portrait
			case .portraitUpsideDown:
				return .portraitUpsideDown
			case .landscapeRight:
				return .landscapeLeft
			default:
				return .portrait
			}
		}
	}
}

@available(iOS 10.0, *)
extension CameraViewController {

	private func reconfigureSession() {
		let inputs = session.inputs
		inputs.forEach { session.removeInput($0) }

		captureDevice = nil
		captureDeviceInput = nil

		configureCaptureDevice()
		configureCaptureDeviceInput()
	}

	private func configureSession() {
		session.beginConfiguration()

		if session.canSetSessionPreset(preset) {
			session.sessionPreset = preset
		} else {
			session.sessionPreset = .high
		}

		configureCaptureDevice()
		configureCaptureDeviceInput()
		configureCapturePhotoOutput()
		configureCaptureVideoOutput()

		session.commitConfiguration()
		session.startRunning()
	}

	private func configureCaptureDevice() {
		let device = captureDevice(for: cameraPosition)
		guard let captureDevice = device else { return }

		do {
			try captureDevice.lockForConfiguration()

			if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
				captureDevice.focusMode = .continuousAutoFocus
			}

			if captureDevice.isSmoothAutoFocusSupported {
				captureDevice.isSmoothAutoFocusEnabled = true
			}

			if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
				captureDevice.exposureMode = .continuousAutoExposure
			}

			if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
				captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
			}

			if captureDevice.isLowLightBoostSupported && lowLightBoost {
				captureDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
			}

			captureDevice.unlockForConfiguration()
		} catch {
			print(error)
		}

		self.captureDevice = captureDevice
	}

	private func configureCaptureDeviceInput() {
		do {
			guard let captureDevice = captureDevice else { return }
			let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)

			if session.canAddInput(captureDeviceInput) {
				session.addInput(captureDeviceInput)
			}

			self.captureDeviceInput = captureDeviceInput
		} catch {
			print(error)
		}
	}

	private func configureCapturePhotoOutput() {
		let capturePhotoOutput = AVCapturePhotoOutput()
		capturePhotoOutput.isHighResolutionCaptureEnabled = true

		if #available(iOS 11.0, *) {
			if capturePhotoOutput.isDualCameraDualPhotoDeliverySupported {
				capturePhotoOutput.isDualCameraDualPhotoDeliveryEnabled = true
			}
		}

		if session.canAddOutput(capturePhotoOutput) {
			session.addOutput(capturePhotoOutput)
		}

		self.capturePhotoOutput = capturePhotoOutput
	}

	private func configureCaptureVideoOutput() {
		let captureVideoOutput = AVCaptureVideoDataOutput()
		captureVideoOutput.alwaysDiscardsLateVideoFrames = true
		captureVideoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "CameraViewControllerQueue"))

		if session.canAddOutput(captureVideoOutput) {
			session.addOutput(captureVideoOutput)
		}

		self.captureVideoOutput = captureVideoOutput
	}

	private func captureDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position)
		let devices = session.devices
		let wideAngle = devices.first { $0.position == position }
		return wideAngle
	}
}

@available(iOS 10.0, *)
extension CameraViewController: AVCapturePhotoCaptureDelegate {

	@available(iOS 11.0, *)
	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		DispatchQueue.global(qos: .userInitiated).async {
			guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }

			let orientation = UIImageOrientation(videoOrientation: self.videoOrientation)
			DispatchQueue.main.async { [weak self] in
				let capturedImage = image.fixOrientation().rotated(by: orientation.rotation)
				self?.cameraDelegate?.cameraViewController(captured: capturedImage)
			}
		}
	}

	public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
		if #available(iOS 11.0, *) { } else {
			DispatchQueue.global(qos: .userInitiated).async {
				guard let sampleBuffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil), let image = UIImage(data: data) else { return }
				DispatchQueue.main.async { [weak self] in
					self?.cameraDelegate?.cameraViewController(captured: image)
				}
			}
		}
	}
}
