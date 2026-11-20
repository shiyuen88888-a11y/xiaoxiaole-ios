import AVFoundation
import Foundation

enum SoundKind: Int {
    case swap = 0
    case match = 1
    case perfect = 2
    case win = 3
    case fail = 4
}

/// Pure-Swift synthesized sound effects using AVAudioEngine (zero external audio files needed).
final class SoundEffects {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [SoundKind: AVAudioPCMBuffer] = [:]

    init() {
        let sampleRate: Double = 44100
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        self.format = fmt

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)

        buffers[.swap] = makeToneSequence(notes: [(420, 0.05), (520, 0.05)], volume: 0.16)
        buffers[.match] = makeToneSequence(notes: [(587, 0.07), (784, 0.09)], volume: 0.20)
        buffers[.perfect] = makeToneSequence(notes: [(523, 0.07), (659, 0.07), (784, 0.08), (1046, 0.14)], volume: 0.24)
        buffers[.win] = makeToneSequence(notes: [(523, 0.09), (659, 0.09), (784, 0.09), (1046, 0.22)], volume: 0.24)
        buffers[.fail] = makeToneSequence(notes: [(392, 0.12), (330, 0.12), (262, 0.22)], volume: 0.20)

        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    func play(_ kind: SoundKind) {
        guard let buffer = buffers[kind] else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func makeToneSequence(notes: [(Double, Double)], volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let totalFrames = notes.reduce(0) { $0 + Int($1.1 * sampleRate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        var offset = 0
        for (freq, duration) in notes {
            let count = Int(duration * sampleRate)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                let env = Float(min(1.0, Double(i) / (sampleRate * 0.008)) * max(0.0, 1.0 - Double(i) / Double(count)))
                channel[offset + i] = sin(Float(2.0 * Double.pi * freq * t)) * volume * env
            }
            offset += count
        }
        return buffer
    }
}
