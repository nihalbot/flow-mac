import Foundation
import AVFoundation
import AppKit

public class SoundEngine: ObservableObject {
    public static let shared = SoundEngine()
    
    // In-memory pre-rendered PCM WAV audio buffers
    private var alertCache: [AlertSound: Data] = [:]
    private var clickData: Data?
    
    // Active playback references (retained so ARC doesn't discard during playback)
    private var activeAlertPlayers: [AVAudioPlayer] = []
    private var ambientPlayer: AVAudioPlayer?
    private var metronomeTimer: Timer?
    
    // Sleep/wake state tracking
    private var wasPlayingAmbientBeforeSleep: Bool = false
    private var ambientVolumeBeforeSleep: Float = 0.4
    
    @Published public var isPlayingAmbient: Bool = false
    @Published public var currentAmbientType: AmbientSound = .none
    
    private let sampleRate: Double = 44100.0
    
    public init() {
        precacheAlertSounds()
        clickData = generateClickWav()
        setupSleepWakeObservers()
    }
    
    // MARK: - Sleep / Wake Observers
    
    private func setupSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        
        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Cleanly pause ambient playback before sleep to prevent CoreAudio interruptions
            if self.isPlayingAmbient {
                self.wasPlayingAmbientBeforeSleep = true
                self.ambientVolumeBeforeSleep = self.ambientPlayer?.volume ?? 0.4
                self.ambientPlayer?.pause()
                self.metronomeTimer?.invalidate()
                self.metronomeTimer = nil
            }
        }
        
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Restore ambient audio if it was active before sleep
            if self.wasPlayingAmbientBeforeSleep && self.currentAmbientType != .none {
                self.wasPlayingAmbientBeforeSleep = false
                let type = self.currentAmbientType
                let volume = self.ambientVolumeBeforeSleep
                // Delay 0.5s after wake so macOS audio hardware finishes waking up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.setAmbientSound(type, volume: volume)
                }
            }
        }
    }
    
    // MARK: - Pre-rendering Chimes
    
    private func precacheAlertSounds() {
        for sound in AlertSound.allCases {
            alertCache[sound] = generateAlertWav(sound)
        }
    }
    
    private func generateAlertWav(_ sound: AlertSound) -> Data {
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
        
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)
        
        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let envelope = exp(-decayRate * t)
            var sample: Double = 0.0
            for f in frequencies {
                sample += sin(2.0 * .pi * f.freq * t) * f.gain
            }
            samples[frame] = Float(sample * envelope)
        }
        
        return createWavData(sampleRate: sampleRate, samples: samples)
    }
    
    private func generateClickWav() -> Data {
        let duration: Double = 0.04
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let env = exp(-80.0 * t)
            samples[frame] = Float(sin(2.0 * .pi * 1200.0 * t) * env)
        }
        return createWavData(sampleRate: sampleRate, samples: samples)
    }
    
    private func createWavData(sampleRate: Double, samples: [Float]) -> Data {
        var data = Data()
        let numChannels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = UInt32(sampleRate * Double(numChannels) * Double(bitsPerSample / 8))
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let subchunk2Size: UInt32 = UInt32(samples.count * Int(numChannels) * 2)
        let chunkSize: UInt32 = 36 + subchunk2Size
        
        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        
        // fmt subchunk
        data.append(contentsOf: "fmt ".utf8)
        let subchunk1Size: UInt32 = 16
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        let audioFormat: UInt16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        let sampleRateU32 = UInt32(sampleRate)
        data.append(contentsOf: withUnsafeBytes(of: sampleRateU32.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data subchunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian) { Array($0) })
        
        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            let intSample = Int16(clamped * 32767.0).littleEndian
            let bytes = withUnsafeBytes(of: intSample) { Array($0) }
            data.append(contentsOf: bytes) // Left
            data.append(contentsOf: bytes) // Right
        }
        return data
    }
    
    // MARK: - Alert Chimes Playback
    
    public func playAlert(_ sound: AlertSound, volume: Float = 0.8) {
        guard let data = alertCache[sound] else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = max(0.0, min(1.0, volume))
                player.prepareToPlay()
                player.play()
                
                self.activeAlertPlayers.append(player)
                
                // Automatically release player after playback completes
                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.5) { [weak self] in
                    self?.activeAlertPlayers.removeAll { $0 == player }
                }
            } catch {
                print("Flow SoundEngine: Gracefully skipped alert playback: \(error.localizedDescription)")
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
        ambientPlayer?.stop()
        ambientPlayer = nil
        isPlayingAmbient = false
        currentAmbientType = .none
        wasPlayingAmbientBeforeSleep = false
    }
    
    private func startMetronome(volume: Float) {
        guard let clickData = clickData else { return }
        
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            do {
                let clickPlayer = try AVAudioPlayer(data: clickData)
                clickPlayer.volume = max(0.0, min(1.0, volume))
                clickPlayer.prepareToPlay()
                clickPlayer.play()
                
                self.activeAlertPlayers.append(clickPlayer)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.activeAlertPlayers.removeAll { $0 == clickPlayer }
                }
            } catch {
                // Silently ignore if audio hardware is temporarily unavailable
            }
        }
    }
    
    private func startNoiseGenerator(type: AmbientSound, volume: Float) {
        let duration: Double = 6.0
        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)
        var brownLast: Float = 0.0
        
        for frame in 0..<frameCount {
            let white = Float.random(in: -1.0...1.0)
            var out: Float = 0.0
            
            switch type {
            case .whiteNoise:
                out = white * 0.18
            case .rain:
                out = (white * 0.5 + brownLast * 0.5) * 0.28
                brownLast = out
            case .ocean:
                brownLast = (brownLast + (0.02 * white)) / 1.02
                out = brownLast * 3.0 * 0.32
            default:
                break
            }
            samples[frame] = out
        }
        
        // Smooth loop boundaries (50ms crossfade to eliminate seam click)
        let fadeSamples = Int(sampleRate * 0.05)
        for i in 0..<fadeSamples {
            let factor = Float(i) / Float(fadeSamples)
            samples[i] *= factor
            samples[frameCount - 1 - i] *= factor
        }
        
        let noiseData = createWavData(sampleRate: sampleRate, samples: samples)
        
        do {
            let player = try AVAudioPlayer(data: noiseData)
            player.numberOfLoops = -1 // Infinite seamless loop
            player.volume = max(0.0, min(1.0, volume))
            player.prepareToPlay()
            player.play()
            self.ambientPlayer = player
        } catch {
            print("Flow SoundEngine: Failed to start ambient loop: \(error.localizedDescription)")
        }
    }
}
