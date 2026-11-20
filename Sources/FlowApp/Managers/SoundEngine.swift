import Foundation
import AVFoundation

public class SoundEngine: ObservableObject {
    public static let shared = SoundEngine()
    
    private var engine: AVAudioEngine?
    private var ambientPlayerNode: AVAudioPlayerNode?
    private var ambientBuffer: AVAudioPCMBuffer?
    private var metronomeTimer: Timer?
    
    @Published public var isPlayingAmbient: Bool = false
    @Published public var currentAmbientType: AmbientSound = .none
    
    private let sampleRate: Double = 44100.0
    
    public init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine = AVAudioEngine()
        ambientPlayerNode = AVAudioPlayerNode()
        
        guard let engine = engine, let ambientPlayerNode = ambientPlayerNode else { return }
        
        // Check if output hardware format is valid before attaching
        let outputNode = engine.outputNode
        let hwFormat = outputNode.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 else {
            print("Audio output device not ready or running in headless mode.")
            return
        }
        
        engine.attach(ambientPlayerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(ambientPlayerNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("Sound engine start deferred: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Alert Chimes
    
    public func playAlert(_ sound: AlertSound, volume: Float = 0.8) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.synthesizeAndPlayAlert(sound, volume: volume)
        }
    }
    
    private func synthesizeAndPlayAlert(_ sound: AlertSound, volume: Float) {
        let duration: Double
        let frequencies: [(freq: Double, gain: Double)]
        let decayRate: Double
        
        switch sound {
        case .bell:
            duration = 3.0
            decayRate = 2.0
            frequencies = [(880.0, 0.6), (1760.0, 0.3), (2640.0, 0.1)]
        case .singingBowl:
            duration = 4.5
            decayRate = 0.8
            frequencies = [(261.63, 0.5), (523.25, 0.35), (784.88, 0.15)]
        case .digitalChime:
            duration = 1.8
            decayRate = 3.0
            frequencies = [(587.33, 0.3), (880.0, 0.4), (1174.66, 0.3)]
        case .marimba:
            duration = 1.5
            decayRate = 4.5
            frequencies = [(440.0, 0.5), (880.0, 0.4), (1320.0, 0.1)]
        case .gong:
            duration = 5.0
            decayRate = 0.6
            frequencies = [(110.0, 0.5), (220.0, 0.3), (330.0, 0.2)]
        }
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount
        
        guard let leftChannel = pcmBuffer.floatChannelData?[0],
              let rightChannel = pcmBuffer.floatChannelData?[1] else { return }
        
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-decayRate * t) * Double(volume)
            var sample: Double = 0.0
            
            for f in frequencies {
                sample += sin(2.0 * .pi * f.freq * t) * f.gain
            }
            
            let finalValue = Float(sample * envelope)
            leftChannel[frame] = finalValue
            rightChannel[frame] = finalValue
        }
        
        // Play using a temporary player node
        guard let engine = self.engine else { return }
        let hwFormat = engine.outputNode.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 else { return }
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        let tempNode = AVAudioPlayerNode()
        engine.attach(tempNode)
        engine.connect(tempNode, to: engine.mainMixerNode, format: format)
        tempNode.play()
        tempNode.scheduleBuffer(pcmBuffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tempNode.stop()
                engine.detach(tempNode)
            }
        }
    }
    
    // MARK: - Ambient Background Noise
    
    public func setAmbientSound(_ type: AmbientSound, volume: Float = 0.4) {
        stopAmbient()
        currentAmbientType = type
        
        guard type != .none else { return }
        
        if type == .metronome {
            startMetronome(volume: volume)
            isPlayingAmbient = true
            return
        }
        
        startNoiseGenerator(type: type, volume: volume)
        isPlayingAmbient = true
    }
    
    public func stopAmbient() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        ambientPlayerNode?.stop()
        isPlayingAmbient = false
        currentAmbientType = .none
    }
    
    private func startMetronome(volume: Float) {
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.playClick(volume: volume)
        }
    }
    
    private func playClick(volume: Float) {
        let duration: Double = 0.04
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else { return }
        
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let env = exp(-80.0 * t) * Double(volume)
            let s = Float(sin(2.0 * .pi * 1200.0 * t) * env)
            left[frame] = s
            right[frame] = s
        }
        
        guard let engine = self.engine else { return }
        let clickNode = AVAudioPlayerNode()
        engine.attach(clickNode)
        engine.connect(clickNode, to: engine.mainMixerNode, format: format)
        clickNode.play()
        clickNode.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                clickNode.stop()
                engine.detach(clickNode)
            }
        }
    }
    
    private func startNoiseGenerator(type: AmbientSound, volume: Float) {
        let duration: Double = 5.0 // Loop 5 seconds buffer
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else { return }
        
        var brownLastL: Float = 0.0
        var brownLastR: Float = 0.0
        
        for frame in 0..<Int(frameCount) {
            let whiteL = Float.random(in: -1.0...1.0)
            let whiteR = Float.random(in: -1.0...1.0)
            
            var outL: Float = 0.0
            var outR: Float = 0.0
            
            switch type {
            case .whiteNoise:
                outL = whiteL * 0.2
                outR = whiteR * 0.2
            case .rain: // Pink noise approximation
                outL = (whiteL * 0.5 + brownLastL * 0.5) * 0.3
                outR = (whiteR * 0.5 + brownLastR * 0.5) * 0.3
                brownLastL = outL
                brownLastR = outR
            case .ocean: // Brown noise
                brownLastL = (brownLastL + (0.02 * whiteL)) / 1.02
                brownLastR = (brownLastR + (0.02 * whiteR)) / 1.02
                outL = brownLastL * 3.0 * 0.35
                outR = brownLastR * 3.0 * 0.35
            default:
                break
            }
            
            left[frame] = outL * volume
            right[frame] = outR * volume
        }
        
        guard let engine = self.engine, let player = self.ambientPlayerNode else { return }
        let hwFormat = engine.outputNode.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 else { return }
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
}
