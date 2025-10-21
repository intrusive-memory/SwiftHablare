//
//  VoiceProviderWidget.swift
//  SwiftHablare
//
//  Voice provider selection widget for choosing between available TTS providers
//

import SwiftUI
import SwiftData

/// Voice provider widget that displays available voice providers for selection
public struct VoiceProviderWidget: View {
    @ObservedObject var providerManager: VoiceProviderManager

    public init(providerManager: VoiceProviderManager) {
        self.providerManager = providerManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Voice Provider")
                .font(.headline)

            // Provider list (dynamic, based on registered providers)
            VStack(spacing: 8) {
                ForEach(providerManager.getRegisteredProviders()) { providerInfo in
                    ProviderInfoRow(
                        providerInfo: providerInfo,
                        isSelected: providerManager.currentProviderId == providerInfo.id
                    )
                    .onTapGesture {
                        providerManager.switchProvider(to: providerInfo.id)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.systemBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
    }
}

/// Row view for displaying a voice provider in the widget (new dynamic version)
public struct ProviderInfoRow: View {
    public let providerInfo: VoiceProviderInfo
    public let isSelected: Bool

    public init(providerInfo: VoiceProviderInfo, isSelected: Bool) {
        self.providerInfo = providerInfo
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                )

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(providerInfo.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)

                HStack(spacing: 4) {
                    // Configuration status
                    Image(systemName: providerInfo.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(providerInfo.isConfigured ? .green : .orange)

                    Text(providerInfo.isConfigured ? "Configured" : "Not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.systemBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1.5)
        )
    }

    /// Icon name for the provider (with fallback for custom providers)
    private var iconName: String {
        // Try to match known provider IDs
        switch providerInfo.id {
        case "elevenlabs":
            return "waveform.circle.fill"
        case "apple":
            return "speaker.wave.3.fill"
        default:
            return "megaphone.fill"  // Default icon for custom providers
        }
    }
}

/// Row view for displaying a voice provider in the widget (deprecated enum-based version)
@available(*, deprecated, message: "Use ProviderInfoRow instead")
public struct ProviderRow: View {
    public let providerType: VoiceProviderType
    public let isSelected: Bool
    public let isConfigured: Bool

    public var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                )

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(providerType.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)

                HStack(spacing: 4) {
                    // Configuration status
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isConfigured ? .green : .orange)

                    Text(isConfigured ? "Configured" : "Not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.systemBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1.5)
        )
    }

    /// Icon name for the provider
    private var iconName: String {
        switch providerType {
        case .elevenlabs:
            return "waveform.circle.fill"
        case .apple:
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        VoiceProviderWidget(
            providerManager: VoiceProviderManager(
                modelContext: PreviewContainer.previewModelContext
            )
        )
        .frame(width: 400)
    }
    .padding()
}

// Helper for preview
private struct PreviewContainer {
    static var previewModelContext: ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: VoiceModel.self, AudioFile.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
