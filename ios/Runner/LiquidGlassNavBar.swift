import Flutter
import UIKit
import SwiftUI

// Native Liquid Glass bottom nav (iOS 26+), bridged into Flutter as a
// PlatformView — Flutter has no equivalent widget for the real `.glassEffect()`
// material. Registration is gated by `#available(iOS 26.0, *)` in
// AppDelegate; Flutter decides whether to instantiate this view based on
// `checkLiquidGlassSupport`, falling back to the legacy Flutter nav otherwise.

@available(iOS 26.0, *)
final class LiquidGlassNavBarFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassNavBarPlatformView(frame: frame, viewId: viewId, messenger: messenger, args: args)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 26.0, *)
final class LiquidGlassNavBarModel: ObservableObject {
    @Published var currentIndex: Int
    var onTap: (Int) -> Void = { _ in }

    init(currentIndex: Int) {
        self.currentIndex = currentIndex
    }
}

@available(iOS 26.0, *)
final class LiquidGlassNavBarPlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<LiquidGlassNavBarView>
    private let model: LiquidGlassNavBarModel
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
        let initialIndex = (args as? [String: Any])?["currentIndex"] as? Int ?? 0
        let model = LiquidGlassNavBarModel(currentIndex: initialIndex)
        self.model = model
        self.channel = FlutterMethodChannel(
            name: "spark/liquid_glass_nav_bar_\(viewId)",
            binaryMessenger: messenger
        )
        self.hostingController = UIHostingController(rootView: LiquidGlassNavBarView(model: model))
        super.init()

        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = frame
        hostingController.safeAreaRegions = []

        model.onTap = { [weak self] index in
            self?.channel.invokeMethod("onTap", arguments: index)
        }

        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "setCurrentIndex", let index = call.arguments as? Int {
                self?.model.currentIndex = index
            }
            result(nil)
        }
    }

    func view() -> UIView {
        hostingController.view
    }
}

// A single physical glass bubble that tracks the finger 1:1 while dragging
// (no animation lag — that's what makes it feel "liquid") and springs back
// to the nearest tab automatically when released. The spring-back is
// SwiftUI's own built-in @GestureState reset animation, not hand-rolled.
@available(iOS 26.0, *)
struct LiquidGlassNavBarView: View {
    @ObservedObject var model: LiquidGlassNavBarModel
    @GestureState private var dragX: CGFloat?

    // Bubble tint: lighter than the (dark) base bar so it stays visible
    // against it, but neutral gray rather than an accent color.
    private let bubbleTint = Color.white.opacity(0.28)
    private let icons = ["house.fill", "person.fill"]

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(icons.count)
            let bubbleX = dragX ?? (tabWidth * (CGFloat(model.currentIndex) + 0.5))
            let highlighted = tabIndex(for: bubbleX, tabWidth: tabWidth)

            ZStack {
                // Glass layer only — GlassEffectContainer groups every
                // .glassEffect() child into its own compositing pass, so
                // anything without .glassEffect() (the icons) must live
                // OUTSIDE it, or it ends up rendered underneath the blur
                // regardless of ZStack order.
                GlassEffectContainer {
                    ZStack {
                        // Base frame delimiting the whole bar — subtle, no
                        // tint, just enough to show where the draggable
                        // area is.
                        Capsule()
                            .fill(Color.clear)
                            .glassEffect(.regular, in: Capsule())

                        // Active bubble — tinted, sits on top of the base frame.
                        Capsule()
                            .fill(Color.clear)
                            .glassEffect(.regular.tint(bubbleTint).interactive(), in: Capsule())
                            .frame(width: tabWidth - 16, height: geo.size.height - 12)
                            .position(x: bubbleX, y: geo.size.height / 2)
                    }
                }

                // Icons — a plain SwiftUI layer on top of the glass, never
                // part of its compositing group, so they stay sharp.
                HStack(spacing: 0) {
                    ForEach(0..<icons.count, id: \.self) { i in
                        Image(systemName: icons[i])
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(i == highlighted ? .white : Color.white.opacity(0.8))
                            .frame(width: tabWidth, height: geo.size.height)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragX) { value, state, _ in
                        state = clampedX(value.location.x, tabWidth: tabWidth, totalWidth: geo.size.width)
                    }
                    .onEnded { value in
                        let index = tabIndex(
                            for: clampedX(value.location.x, tabWidth: tabWidth, totalWidth: geo.size.width),
                            tabWidth: tabWidth
                        )
                        model.currentIndex = index
                        model.onTap(index)
                    }
            )
        }
        .frame(height: 60)
    }

    private func clampedX(_ x: CGFloat, tabWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        min(max(x, tabWidth / 2), totalWidth - tabWidth / 2)
    }

    private func tabIndex(for x: CGFloat, tabWidth: CGFloat) -> Int {
        guard tabWidth > 0 else { return model.currentIndex }
        let raw = Int(x / tabWidth)
        return min(max(raw, 0), icons.count - 1)
    }
}
