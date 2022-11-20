//
//  Audio.swift
//  Tune
//
//  Created by Korotnev Pavel on 13.11.2022.
//


import AVFoundation
import Accelerate


public class Audio: CALayer, ObservableObject {

    override init() {
        super.init()
        configureCaptureSession()  /// Получение доступа к микрофону
        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
        startRunning()             /// Запуск чтения с микрофона
    }

    @Published var note : String = " "

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override public init(layer: Any) { super.init(layer: layer) }
    

    static let sampleCount: Int = 22050                       /// Кол-во семплов на фрейм ( ~ 0.1 секунды)
    static let zeroSample: Int  = 65536                       /// Кол-во семплов на фрейм после заполнения нулями
    static let hopCount: Int    = 22050                       /// Кол-во семплов перекрытия
    static let freqRes: Double  = 44100 / Double(zeroSample)  /// Разрешение по частоте

    let captureSession = AVCaptureSession()
    let audioOutput    = AVCaptureAudioDataOutput()
    
    let captureQueue   = DispatchQueue(label: "captureQueue",
                                       qos: .userInitiated,
                                       attributes: [],
                                       autoreleaseFrequency: .workItem)
    
    let sessionQueue   = DispatchQueue(label: "sessionQueue",
                                       attributes: [],
                                       autoreleaseFrequency: .workItem)
    
    let forwardDCT     = vDSP.DCT(count: zeroSample, transformType: .II)!
    
    let hanningWindow  = vDSP.window(ofType: Float.self,
                                     usingSequence: .hanningDenormalized,
                                     count: zeroSample,
                                     isHalfWindow: false)

    let dispatchSemaphore = DispatchSemaphore(value: 1)

    var rawAudioData          = [Int16]()                                 /// Буфер с сырыми данными с микрофона от AVFoundation.
    var timeDomainBuffer      = [Float](repeating: 0, count: zeroSample)  /// Буфер с актуальным фреймом до DCT
    var frequencyDomainBuffer = [Float](repeating: 0, count: zeroSample)  /// Буфер с актуальным фреймом после DCT


    /// DCT
    func process(values: [Int16]) {
        dispatchSemaphore.wait()
        vDSP.convertElements(of: values, to: &timeDomainBuffer)                    /// Конвертация `Int16` во `Float`
        vDSP.multiply(timeDomainBuffer, hanningWindow, result: &timeDomainBuffer)  /// Применение сглаживающего окна
        forwardDCT.transform(timeDomainBuffer, result: &frequencyDomainBuffer)     /// Применение DCT
        vDSP.absolute(frequencyDomainBuffer, result: &frequencyDomainBuffer)
        note = find_note(frequencyDomainBuffer)
        dispatchSemaphore.signal()
    }
    
    
    func find_note(_ window: [Float]) -> String {
        let max = window.max()
        let ind = window.firstIndex(of: max!)!
        let hz  = Double(ind) * Audio.freqRes
        
        for (borders, noteName) in allNotesHz {
            if (borders[0] <= hz && hz <= borders[1]) {
                return noteName
            }
        }
        return " "
    }
}



extension Audio: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        
        guard let data = audioBufferList.mBuffers.mData else { return }
        
        if self.rawAudioData.count < Audio.sampleCount {
            let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
            let ptr = data.bindMemory(to: Int16.self, capacity: actualSampleCount)
            let buf = UnsafeBufferPointer(start: ptr, count: actualSampleCount)
            rawAudioData.append(contentsOf: Array(buf))
        }
        
        while self.rawAudioData.count >= Audio.sampleCount {
            var dataToProcess = Array(self.rawAudioData[0 ..< Audio.sampleCount])
            self.rawAudioData.removeFirst(Audio.hopCount)
            dataToProcess.append(contentsOf: [Int16](repeating: 0, count: Audio.zeroSample-Audio.sampleCount))
            self.process(values: dataToProcess)
        }
    }
    
    
    
    func configureCaptureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    fatalError("Требуется доступ к микрофону!")
                } else {
                    self.configureCaptureSession()
                    self.sessionQueue.resume()
                }
            }
            return
        default:
            fatalError("Требуется доступ к микрофону!")
        }
        
        captureSession.beginConfiguration()
        
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        } else {
            fatalError("Can't add `audioOutput`.")
        }
        
        guard
            let microphone = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
            let microphoneInput = try? AVCaptureDeviceInput(device: microphone) else {
                fatalError("Can't create microphone.")
            }
        if captureSession.canAddInput(microphoneInput) {
            captureSession.addInput(microphoneInput)
        }
        captureSession.commitConfiguration()
    }
    
    
    
    /// Начало чтения аудио
    func startRunning() {
        sessionQueue.async {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                self.captureSession.startRunning()
            }
        }
    }
}

