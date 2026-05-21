import AppKit

final class OpacityBar: NSView {
    static let height: CGFloat = 26

    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let captionLabel = NSTextField(labelWithString: "Opacity")

    var onChange: ((CGFloat) -> Void)?

    init(initialOpacity: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        // Solid bar so the slider remains readable even when the window is heavily faded.
        layer?.backgroundColor = NSColor.black.cgColor

        captionLabel.textColor = .secondaryLabelColor
        captionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionLabel)

        slider.minValue = Double(Prefs.minOpacity)
        slider.maxValue = Double(Prefs.maxOpacity)
        slider.doubleValue = Double(Prefs.clamp(initialOpacity))
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)

        valueLabel.alignment = .right
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            captionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: captionLabel.trailingAnchor, constant: 8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 42),
        ])

        refreshLabel()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setOpacity(_ v: CGFloat) {
        slider.doubleValue = Double(Prefs.clamp(v))
        refreshLabel()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let v = Prefs.clamp(CGFloat(sender.doubleValue))
        refreshLabel()
        onChange?(v)
    }

    private func refreshLabel() {
        valueLabel.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%"
    }
}
