import BattleApp
import Foundation
import SwiftUI
import UIKit

struct RootView: View {
    @State private var director = Director()
    @State private var frame = Frame.opening
    @ScaledMetric(relativeTo: .body) private var unit = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: frame.layout.gap) {
                readout
                field(proxy)
                row(frame.secondary, height: frame.layout.secondary, proxy)
                row([frame.primary], height: frame.layout.primary, proxy)
            }
            .padding(.vertical, frame.layout.pad)
            .onChange(of: surface(proxy), initial: true) { _, now in
                frame = director.frame(surface: now, seconds: 0)
            }
            .onChange(of: frame.wantsFrames, initial: true) { _, wanted in
                UIApplication.shared.isIdleTimerDisabled = wanted
            }
            .onChange(of: frame.banner) { _, announced in
                if let announced {
                    UIAccessibility.post(notification: .announcement, argument: announced.spoken)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
    }

    private func surface(_ proxy: GeometryProxy) -> Surface {
        Surface(
            width: proxy.size.width,
            height: proxy.size.height,
            unit: unit,
            reduceMotion: reduceMotion)
    }

    private var readout: some View {
        HStack(spacing: 0) {
            cell(frame.clock)
            ForEach(frame.counts.indices, id: \.self) { index in
                cell("\(Words.glyphs[index]) \(frame.counts[index])")
            }
        }
        .frame(height: frame.layout.readout)
    }

    private func cell(_ reading: String) -> some View {
        Text(reading)
            .font(.system(size: frame.layout.body, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
    }

    private func field(_ proxy: GeometryProxy) -> some View {
        ZStack {
            if frame.phase == .landing {
                title(proxy)
            } else {
                battlefield(proxy)
            }
            if let banner = frame.banner {
                celebration(banner)
            }
        }
        .frame(height: frame.layout.field.height)
    }

    private func title(_ proxy: GeometryProxy) -> some View {
        Button {
            frame = director.handle(frame.primary.intent, surface: surface(proxy))
        } label: {
            VStack(alignment: .leading, spacing: frame.layout.gap) {
                ForEach(Words.glyphs.indices, id: \.self) { index in
                    HStack(spacing: frame.layout.gap) {
                        Text(Words.glyphs[index])
                            .font(.system(size: frame.layout.art))
                        Text(Words.names[index])
                            .font(.system(size: frame.layout.body, weight: .heavy))
                            .textCase(.uppercase)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private func battlefield(_ proxy: GeometryProxy) -> some View {
        TimelineView(.animation(paused: !frame.wantsFrames)) { schedule in
            Canvas { context, _ in
                let soldiers = Words.glyphs.map {
                    context.resolve(Text($0).font(.system(size: frame.soldierPoints)))
                }
                for dot in frame.soldiers {
                    context.draw(soldiers[dot.glyph], at: CGPoint(x: dot.x, y: dot.y))
                }
                let confetti = Words.glyphs.map {
                    context.resolve(Text($0).font(.system(size: frame.confettiPoints)))
                }
                for dot in frame.confetti {
                    context.draw(confetti[dot.glyph], at: CGPoint(x: dot.x, y: dot.y))
                }
            }
            .frame(width: frame.layout.field.width, height: frame.layout.field.height)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Battlefield")
            .accessibilityValue(frame.summary)
            .accessibilityAddTraits(.updatesFrequently)
            .onChange(of: schedule.date) { was, now in
                frame = director.frame(
                    surface: surface(proxy), seconds: now.timeIntervalSince(was))
            }
        }
    }

    private func celebration(_ banner: Banner) -> some View {
        VStack(spacing: frame.layout.gap) {
            Text(banner.winner)
                .font(.system(size: frame.layout.title, weight: .black))
            Text(banner.duration)
                .font(.system(size: frame.layout.body, weight: .semibold))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(frame.layout.gap)
        .background {
            RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white, lineWidth: 4)
        }
    }

    private func row(_ controls: [Control], height: Double, _ proxy: GeometryProxy) -> some View {
        HStack(spacing: frame.layout.gap) {
            ForEach(controls, id: \.title) { control in
                Button {
                    frame = director.handle(control.intent, surface: surface(proxy))
                } label: {
                    Text(control.title)
                        .font(.system(size: frame.layout.body, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(control.selected ? Color.black : Color.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(control.selected ? Color.white : Color.black)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white, lineWidth: control.selected ? 6 : 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(control.spoken)
                .accessibilityAddTraits(control.selected ? .isSelected : [])
            }
        }
        .frame(height: height)
        .padding(.horizontal, frame.layout.gap)
    }
}
