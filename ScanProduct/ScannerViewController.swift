import UIKit
import AVFoundation

protocol ScannerViewControllerDelegate: AnyObject {
    func didScan(code: String)
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: ScannerViewControllerDelegate?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    private let scanRectWidth: CGFloat = 300
    private let scanRectHeight: CGFloat = 120

    private var scanningLine: CAGradientLayer!
    private var scanningTimer: CADisplayLink?
    private var linePosition: CGFloat = 0
    private var lineMovingDown = true

    private var flashButton: UIButton!

    private var scanRectFrame: CGRect {
        return CGRect(
            x: (view.bounds.width - scanRectWidth)/2,
            y: (view.bounds.height - scanRectHeight)/2,
            width: scanRectWidth,
            height: scanRectHeight
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScanner()
        setupMask()
        setupScanningLine()
        setupBackButton()
        setupFlashButton()
        startLineAnimation()
        addTapToFocus()
    }

    func setupScanner() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else { return }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .code128]

            let rect = scanRectFrame
            metadataOutput.rectOfInterest = CGRect(
                x: rect.origin.y / view.bounds.height,
                y: rect.origin.x / view.bounds.width,
                width: rect.height / view.bounds.height,
                height: rect.width / view.bounds.width
            )
        } else { return }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    func setupMask() {
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(rect: scanRectFrame).reversing())
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        view.layer.addSublayer(maskLayer)

        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(rect: scanRectFrame).cgPath
        borderLayer.strokeColor = UIColor.green.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 2
        view.layer.addSublayer(borderLayer)
    }

    func setupScanningLine() {
        scanningLine = CAGradientLayer()
        scanningLine.frame = CGRect(x: 0, y: 0, width: scanRectWidth, height: 4)
        scanningLine.colors = [
            UIColor.clear.cgColor,
            UIColor.green.withAlphaComponent(0.8).cgColor,
            UIColor.clear.cgColor
        ]
        scanningLine.startPoint = CGPoint(x: 0, y: 0.5)
        scanningLine.endPoint = CGPoint(x: 1, y: 0.5)

        let container = UIView(frame: scanRectFrame)
        container.clipsToBounds = true
        container.addSubview(UIView()) // 空占位，避免警告
        container.layer.addSublayer(scanningLine)
        container.backgroundColor = .clear
        container.tag = 999 // 标记
        view.addSubview(container)

        linePosition = 0
        lineMovingDown = true
    }

    func startLineAnimation() {
        scanningTimer = CADisplayLink(target: self, selector: #selector(updateLine))
        scanningTimer?.add(to: .main, forMode: .common)
    }

    @objc func updateLine() {
        guard let container = view.viewWithTag(999) else { return }
        let maxY = container.bounds.height - scanningLine.bounds.height
        if lineMovingDown {
            linePosition += 1
            if linePosition >= maxY {
                lineMovingDown = false
            }
        } else {
            linePosition -= 1
            if linePosition <= 0 {
                lineMovingDown = true
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scanningLine.frame.origin.y = linePosition
        CATransaction.commit()
    }

    func stopLineAnimation() {
        scanningTimer?.invalidate()
        scanningTimer = nil
    }

    func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("返回", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backButton.layer.cornerRadius = 5
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 60),
            backButton.heightAnchor.constraint(equalToConstant: 35)
        ])
    }

    func setupFlashButton() {
        flashButton = UIButton(type: .system)
        flashButton.setTitle("打开闪光灯", for: .normal)
        flashButton.setTitleColor(.white, for: .normal)
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 5
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        view.addSubview(flashButton)

        NSLayoutConstraint.activate([
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 120),
            flashButton.heightAnchor.constraint(equalToConstant: 35)
        ])
    }

    @objc func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                flashButton.setTitle("关闭闪光灯", for: .normal)
            } else {
                device.torchMode = .off
                flashButton.setTitle("打开闪光灯", for: .normal)
            }
            device.unlockForConfiguration()
        } catch {
            print("闪光灯切换失败: \(error)")
        }
    }

    func addTapToFocus() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusOnTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func focusOnTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                let focusPoint = CGPoint(x: point.y / view.bounds.height, y: 1.0 - point.x / view.bounds.width)
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                let exposurePoint = CGPoint(x: point.y / view.bounds.height, y: 1.0 - point.x / view.bounds.width)
                device.exposurePointOfInterest = exposurePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("聚焦失败: \(error)")
        }
    }

    @objc func dismissSelf() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        stopLineAnimation()
        dismiss(animated: true)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let code = metadataObject.stringValue {
            captureSession.stopRunning()
            stopLineAnimation()
            delegate?.didScan(code: code)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        stopLineAnimation()
    }
}
