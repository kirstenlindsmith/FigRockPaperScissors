import BattleApp
import Foundation
import SwiftUI
import UIKit

struct RootView: View {
    private static let remembered = "armies"

    @State private var director: Director
    @State private var frame: Frame
    @ScaledMetric(relativeTo: .body) private var unit = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        let opened = Director(
            record: UserDefaults.standard.stringArray(forKey: RootView.remembered) ?? [])
        _director = State(initialValue: opened)
        _frame = State(initialValue: opened.frame(surface: .zero, seconds: 0))
    }

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
            .onChange(of: frame.record) { _, now in
                UserDefaults.standard.set(now, forKey: RootView.remembered)
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
                cell("\(frame.armies[index].glyph) \(frame.counts[index])")
            }
        }
        .frame(height: frame.layout.readout)
    }

    private func cell(_ reading: String) -> some View {
        Text(reading)
            .font(.system(size: frame.layout.body, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity)
    }

    private func field(_ proxy: GeometryProxy) -> some View {
        ZStack {
            if frame.phase == .landing {
                title(proxy)
            } else if frame.phase == .choosing {
                chooser(proxy)
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
        VStack(alignment: .leading, spacing: frame.layout.gap) {
            ForEach(frame.armies.indices, id: \.self) { index in
                HStack(spacing: frame.layout.gap) {
                    Text(frame.armies[index].glyph)
                        .font(.system(size: frame.layout.art))
                    Text(frame.armies[index].role)
                        .font(.system(size: frame.layout.body, weight: .heavy))
                        .textCase(.uppercase)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            frame = director.handle(frame.primary.intent, surface: surface(proxy))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frame.legend)
    }

    private func chooser(_ proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: frame.layout.gap) {
                ForEach(frame.armies.indices, id: \.self) { index in
                    block(index, proxy)
                }
            }
        }
        .tint(Color.white)
    }

    private func block(_ index: Int, _ proxy: GeometryProxy) -> some View {
        let army = frame.armies[index]
        let typedGlyph = Binding<String>(
            get: { frame.armies[index].typedGlyph },
            set: { frame = director.handle(.glyph(index, $0), surface: surface(proxy)) })
        let typedName = Binding<String>(
            get: { frame.armies[index].typedName },
            set: { frame = director.handle(.name(index, $0), surface: surface(proxy)) })
        let soldiers = Binding<Double>(
            get: { Double(frame.armies[index].soldiers) },
            set: { frame = director.handle(.soldiers(index, $0), surface: surface(proxy)) })
        return VStack(spacing: frame.layout.gap) {
            HStack(spacing: frame.layout.gap) {
                Text(army.glyph)
                    .font(.system(size: frame.layout.body))
                Text(army.role)
                    .font(.system(size: frame.layout.body, weight: .heavy))
                    .textCase(.uppercase)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: frame.layout.body)

            HStack(spacing: frame.layout.gap) {
                draft(placeholder: army.glyph, spoken: army.glyphLabel, text: typedGlyph)
                draft(placeholder: army.name, spoken: army.nameLabel, text: typedName)
            }
            .frame(height: frame.layout.secondary)

            HStack(spacing: frame.layout.gap) {
                Slider(value: soldiers, in: Army.range)
                    .accessibilityLabel(army.soldiersLabel)
                    .accessibilityValue(String(army.soldiers))
                Text(String(army.soldiers))
                    .font(.system(size: frame.layout.body, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: frame.layout.secondary)
            }
            .frame(height: frame.layout.secondary)
        }
        .padding(.horizontal, frame.layout.gap)
    }

    private func draft(placeholder: String, spoken: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: frame.layout.body, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: frame.layout.slot(2), height: frame.layout.secondary)
            .boxed(selected: false)
            .accessibilityLabel(spoken)
    }

    private func battlefield(_ proxy: GeometryProxy) -> some View {
        TimelineView(.animation(paused: !frame.wantsFrames)) { schedule in
            Canvas { context, _ in
                let soldiers = frame.armies.map {
                    context.resolve(Text($0.glyph).font(.system(size: frame.soldierPoints)))
                }
                for dot in frame.soldiers {
                    context.draw(soldiers[dot.glyph], at: CGPoint(x: dot.x, y: dot.y))
                }
                let confetti = frame.armies.map {
                    context.resolve(Text($0.glyph).font(.system(size: frame.confettiPoints)))
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
                        .frame(width: frame.layout.slot(controls.count), height: height)
                        .boxed(selected: control.selected)
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

extension View {
    fileprivate func boxed(selected: Bool) -> some View {
        background {
            RoundedRectangle(cornerRadius: 16)
                .fill(selected ? Color.white : Color.black)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white, lineWidth: selected ? 6 : 2)
        }
    }
}
