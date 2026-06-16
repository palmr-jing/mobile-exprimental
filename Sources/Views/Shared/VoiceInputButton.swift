import SwiftUI

struct VoiceInputButton: View {
    @ObservedObject var speechService: SpeechRecognitionService
    var size: CGFloat = 72
    var onSubmit: (String) -> Void

    @State private var isPressing = false
    @State private var permissionChecked = false
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if speechService.isRecording {
                transcriptOverlay
            }

            ZStack {
                // Audio level ring
                if speechService.isRecording {
                    Circle()
                        .stroke(DS.Colors.accent.opacity(0.3), lineWidth: 4)
                        .frame(width: size + 20, height: size + 20)

                    Circle()
                        .trim(from: 0, to: CGFloat(speechService.audioLevel))
                        .stroke(DS.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: size + 20, height: size + 20)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.1), value: speechService.audioLevel)

                    // Pulsing outer ring
                    Circle()
                        .stroke(DS.Colors.accent.opacity(0.15), lineWidth: 2)
                        .frame(width: size + 36, height: size + 36)
                        .scaleEffect(isPressing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPressing)
                }

                // Main button
                Circle()
                    .fill(speechService.isRecording ? DS.Colors.red : DS.Colors.accent)
                    .frame(width: size, height: size)
                    .shadow(color: (speechService.isRecording ? DS.Colors.red : DS.Colors.accent).opacity(0.3),
                            radius: speechService.isRecording ? 12 : 6,
                            y: speechService.isRecording ? 0 : 3)

                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(isPressing ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                isPressing = pressing
                if pressing {
                    handlePressStart()
                } else if speechService.isRecording {
                    handlePressEnd()
                }
            }, perform: {})
            .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Voice input needs microphone and speech recognition access. Enable them in Settings.")
            }

            if let error = speechService.errorMessage {
                Text(error)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var transcriptOverlay: some View {
        Group {
            if speechService.transcript.isEmpty {
                Text("Listening...")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.secondary)
                    .italic()
            } else {
                Text(speechService.transcript)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(minHeight: 40)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: speechService.transcript)
    }

    private func handleTap() {
        if speechService.isRecording {
            let text = speechService.stopRecording()
            submitIfNonEmpty(text)
        } else {
            startRecording()
        }
    }

    private func handlePressStart() {
        triggerHaptic(.medium)
        startRecording()
    }

    private func handlePressEnd() {
        triggerHaptic(.light)
        let text = speechService.stopRecording()
        submitIfNonEmpty(text)
    }

    private func startRecording() {
        guard !speechService.isRecording else { return }

        if speechService.permissionDenied {
            showPermissionAlert = true
            return
        }

        if speechService.needsPermission {
            Task {
                let granted = await speechService.requestPermissions()
                if granted {
                    triggerHaptic(.medium)
                    speechService.startRecording()
                } else {
                    showPermissionAlert = true
                }
            }
            return
        }

        triggerHaptic(.medium)
        speechService.startRecording()
    }

    private func submitIfNonEmpty(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        triggerHaptic(.heavy)
        onSubmit(trimmed)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// Compact inline mic for chat input bars
struct CompactVoiceButton: View {
    @ObservedObject var speechService: SpeechRecognitionService
    var onTranscriptReady: (String) -> Void

    @State private var showPermissionAlert = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            ZStack {
                if speechService.isRecording {
                    Circle()
                        .fill(DS.Colors.red.opacity(0.15))
                        .frame(width: 40, height: 40)
                }

                Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(speechService.isRecording ? DS.Colors.red : DS.Colors.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice input needs microphone and speech recognition access. Enable them in Settings.")
        }
    }

    private func handleTap() {
        if speechService.isRecording {
            let text = speechService.stopRecording()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTranscriptReady(trimmed)
            }
        } else {
            if speechService.permissionDenied {
                showPermissionAlert = true
                return
            }
            if speechService.needsPermission {
                Task {
                    let granted = await speechService.requestPermissions()
                    if granted {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        speechService.startRecording()
                    } else {
                        showPermissionAlert = true
                    }
                }
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            speechService.startRecording()
        }
    }
}
