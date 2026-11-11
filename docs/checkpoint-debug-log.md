# Browsing log evidence — 2026-11-10

Source: user-pasted device debug log for [current UX feedback](checkpoint-ux-issues.md). This file preserves representative excerpts and groups repeated messages; it is not a verbatim copy of the entire log. Memory addresses and repeated instances are omitted below. No action timestamps, call stacks, device model, or iOS version were supplied. Relationships to reported bugs remain unconfirmed.

## Navigation prompt constraints

Repeated “Unable to simultaneously satisfy constraints” involving:

```text
UILabel.centerX == UIViewLayoutMarginsGuide.centerX
UILabel.trailing <= UIViewLayoutMarginsGuide.trailing
UILabel.leading >= UIViewLayoutMarginsGuide.leading
'UIView-Encapsulated-Layout-Width' _UINavigationBarModernPromptView.width == 0
'UIView-leftMargin-guide-constraint' ... 16 ...
'UIView-rightMargin-guide-constraint' ... 16 ...
```

UIKit breaks the label's trailing or leading constraint to recover. The log suggests setting a symbolic breakpoint at `UIViewAlertForUnsatisfiableConstraints`.

## Alert constraints

Repeated conflicts involving `_UIAlertControllerPhoneTVMacView`:

```text
NSAutoresizingMaskLayoutConstraint UIView.width == 320
_UIAlertControllerPhoneTVMacView.width >= UIView.width
UIView.width == _UIAlertControllerPhoneTVMacView.width
UIView.width == 366
```

UIKit recovers by breaking the 366-point width constraint.

## Animation and conversion diagnostics

```text
Decomposition of 'transform' was requested on layer (delegate LittleGlowView) while a composite animation is already running on it. Enable decomposition for all
animations running simultaneously on this layer.
Conversion error! {{0, 874}, {402, 0}} was converted to {{-1.076122672508198, 877.01478641840083}, {403.98138006571742, 0}}
Conversion error! {{0, 874}, {402, 0}} was converted to {{-440.15910222558466, 1274.9613201853613}, {575.75419008492565, 0}}
```

Many intermediate conversion errors were repeated with changing coordinates and zero heights.

## Other diagnostic groups

```text
cannot add handler to 0 from 0 - dropping
non-launching port is incompatible with service identifier "com.apple.PointerUI.pointeruid.default-service"
59638328 Plugin query method called
(501) Invalidation handler invoked, clearing connection
(501) personaAttributesForPersonaType for type:0 failed with error Error Domain=NSCocoaErrorDomain Code=4099
```

The persona message names an invalidated `com.apple.mobile.usermanagerd.xpc` connection.

```text
LaunchServices: store (null) or url (null) was nil: Error Domain=NSOSStatusErrorDomain Code=-54 "process may not map database"
Attempt to map database failed: permission was denied. This attempt will not be retried.
Failed to initialize client context with error Error Domain=NSOSStatusErrorDomain Code=-54 "process may not map database"
Reading from public effective user settings.
No scene exists for identity: com.apple.InputUI.keyboard:KeyboardInputScene-com.apple.frontboard.systemappservices/FBSceneManager:sceneID%3Akashmoney.TagWallet-default
```

LaunchServices and handler messages repeat throughout the supplied log. These messages alone do not establish a required permissions change or a root cause. Reproduce and correlate before deciding which diagnostics require app changes.
