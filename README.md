# 🛡️ FlutterInspector SDK

巡检助手是一款为 Flutter 应用量身定制的**生产级全自动 UI 审计与异常监测系统**。它能够在静默运行的同时，捕捉 UI 越界异常，并支持无人值守的自动化路径遍历测试。

---

## ⚡ 1. 一行命令集成

在应用入口 `main.dart` 中，只需一行初始化代码即可激活防御系统。

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 模式一：静默监测 (默认，实时保存)
  await FlutterInspector.init(autoTest: false); 

  // 🤖 模式二：自动化审计 (执行完毕后统一保存)
  // autoTest: 开启全自动巡检
  // maxClicks: 每个按钮/路径的最大尝试点击次数（决定审计深度）
  // await FlutterInspector.init(autoTest: true, maxClicks: 3);

  runApp(const MyApp());
}
```

---

## �️ 2. 测试环境 (Debug) 与 线上环境 (Release) 的区别

SDK 具备完善的环境感知能力，确保在不同阶段提供差异化的支持：

| 功能维度 | **Debug 模式 (测试环境)** | **Release 模式 (线上环境)** |
| :--- | :--- | :--- |
| **日志输出** | 极尽详细。初始化及每次保存均输出**完整本地物理路径**。 | 静默优先。仅记录状态同步成功，**不暴露**任何本地路径信息。 |
| **设备识别** | 开启深度识别。尝试捕捉模拟器的“真名”（如 iPhone 17 Pro Max）。 | 基础识别。记录 OS 版本及基础设备分类，保护隐私。 |
| **控制台打印** | `debugPrint` 全量输出，方便开发者排查。 | 仅通过 `dart:developer.log` 输出核心异常，减小对控制台干扰。 |

---

## 💾 3. 日志写入时机

SDK 采用双重保存策略，根据运行模式自动切换：

- **静默监测模式 (`autoTest: false`)**
  - **动态触发**：每 **5 秒** 执行一次“脏位检查”。
  - **写入逻辑**：只要检测到页面切换 (Route Change) 或产生了新的 UI 异常，立即执行异步写入。确保监测数据**实时落盘**。
- **自动化审计模式 (`autoTest: true`)**
  - **总结触发**：机器人遍历任务**彻底结束时**执行唯一一次写入。
  - **写入逻辑**：汇总全量点击路径数据与异常快照，生成完整的单次审计报告。

---

## 📡 4. 日志读取时机 (上传服务器)

SDK 提供了三个标准静态接口，方便随时提取数据上传后端：

- **`FlutterInspector.getLatestSummaryReport()`**
  - **返回形式**：`String`
  - **时机**：实时获取当前内存中的汇总摘要。适用于显示在调试 UI 或即时 API 请求体。
- **`FlutterInspector.getFullErrorHistoryLog()`**
  - **返回形式**：`Future<String>`
  - **时机**：异步读取跨会话的本地异常历史文件。适用于全量错误回溯。
- **`FlutterInspector.getLogFilesForUpload()`**
  - **返回形式**：`Future<List<File>>`
  - **时机**：返回报告文件与日志文件的物理 `File` 句柄。适用于对接 **Multipart 上传** 逻辑。

---

## 📍 报告位置 (仅 Debug 模式可见)
系统启动后请观察控制台：
`🛡️ [Inspector SDK] Sentinel Active. Storage: /.../Documents | Device: ...`
点击路径即可查看生成的 `inspector_report.txt`。
