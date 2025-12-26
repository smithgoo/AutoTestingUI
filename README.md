# AutoTestingUI 🚀

A universal automation and UI overflow detection tool for Flutter. This SDK is designed to be a "plug-and-play" auditor for your Flutter projects, providing automated UI navigation, crash detection, and detailed reporting.

## Features ✨

- **🚀 Auto-Pilot Mode**: Automatically scans the widget tree and simulates user interactions.
- **🛡️ Smart Throttling**: Each UI feature/button is tested **at most 2 times** to ensure broad coverage without getting stuck in loops.
- **🚨 Error Observation**: Automatically intercepts `RenderFlex overflow` warnings and other layout exceptions.
- **📋 Local Reporting**: Generates a detailed audit report (`inspector_report.txt`) saved to the device's documents directory.
- **🔤 Semantic Awareness**: Intelligently identifies buttons by their internal text or icons for readable logs.

## Integration Guide 🛠️

### 1. Structure
Copy the `autotestingui` package to your project's `packages/` directory (or host it on a private Git repo).

### 2. Dependency
Add it to your `pubspec.yaml`:
```yaml
dependencies:
  autotestingui:
    git:
      url: https://github.com/yourusername/AutoTestingUI.git
      ref: main
```

### 3. Usage
Initialize it in your `main.dart` entry point:
```dart
import 'package:autotestingui/autotestingui.dart';

void main() async {
  // Create an instance of the inspector
  final inspector = FlutterInspector(maxClicks: 3);
  await inspector.init();
  
  runApp(MyApp());
}
```

### 4. Inheritance (Advanced)
You can extend the `FlutterInspector` class to customize its behavior:
```dart
class CustomInspector extends FlutterInspector {
  CustomInspector({super.maxClicks = 5});

  @override
  void performTap(Element element) {
    // Custom tap logic
    super.performTap(element);
    // Add additional actions
  }

  @override
  String extractNameFromElement(Element element) {
    // Custom naming logic
    return super.extractNameFromElement(element) + '_custom';
  }
}
```

Then use it:
```dart
final inspector = CustomInspector();
await inspector.init();
```

## How it Works ⚙️
1. **Wake up**: 4 seconds after the app starts, the Robot awakens.
2. **Scan**: It identifies interactable elements (InkWell, Buttons, etc.) and analyzes their semantics.
3. **Act**: It simulates taps on features it hasn't tested enough (threshold: 2).
4. **Report**: Once all reachable features are audited, it generates a comprehensive report on the device.

## Security 🔒
All logic is wrapped in `if (!kDebugMode) return;`. The SDK will **never** run or affect your production/release builds.

---
Developed for high-quality Flutter engineering. 🥂🛡️
