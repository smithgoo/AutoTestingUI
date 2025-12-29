import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';

/// 🛡️ FlutterInspector (Dual-Mode: Monitoring & Automation)
/// 
/// 1. Monitoring Mode (autoTest: false): Real-time 5s auto-save for continuous tracking.
/// 2. Automation Mode (autoTest: true): Summary-only save at the end of audit.
class FlutterInspector {
  static final FlutterInspector _instance = FlutterInspector._internal();
  factory FlutterInspector() => _instance;
  FlutterInspector._internal();

  bool _isAutoPilotRunning = false;
  bool _isAutoTestMode = false;
  final _random = Random();
  
  final Map<String, int> _interactionStats = {}; 
  final List<String> _errorLog = [];
  final List<int> _clickHistory = []; 
  
  String _currentRoute = "Initial";
  String _deviceInfo = "Unknown Device";
  int _maxClicks = 3;
  
  // Track if data has changed since last save
  bool _isDataDirty = false;

  /// Navigator observer for route tracking
  static final NavigatorObserver observer = _InspectorObserver();

  // --------------------------------------------------------------------------
  // PUBLIC API FOR SERVER UPLOAD
  // --------------------------------------------------------------------------

  /// Get the latest summary report string (i18n supported)
  static String getLatestSummaryReport() {
    return _instance._generateReportString();
  }

  /// Get the full historical error log string from the local file.
  static Future<String> getFullErrorHistoryLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/inspector_error_history.log');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return "No historical logs found.";
    } catch (e) {
      return "Failed to read logs: $e";
    }
  }

  /// Get the raw File objects for server upload
  static Future<List<File>> getLogFilesForUpload() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportFile = File('${directory.path}/inspector_report.txt');
      final errorFile = File('${directory.path}/inspector_error_history.log');
      
      List<File> files = [];
      if (await reportFile.exists()) files.add(reportFile);
      if (await errorFile.exists()) files.add(errorFile);
      return files;
    } catch (e) {
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // CORE LOGIC
  // --------------------------------------------------------------------------

  /// Initialize the SDK
  static Future<void> init({
    bool autoTest = false,
    int maxClicks = 3,
  }) async {
    final instance = FlutterInspector();
    instance._maxClicks = maxClicks;
    instance._isAutoTestMode = autoTest;
    
    // 1. Identify Detailed Device Info
    instance._deviceInfo = await instance._fetchDeviceInfo();
    
    // 1.1 Immediate Directory Visibility (Only in Debug)
    final directory = await getApplicationDocumentsDirectory();
    if (kDebugMode) {
      _universalLog(
        "${_I18n.t('sentinel_active')}. Storage: ${directory.path} | Device: ${instance._deviceInfo}",
        name: '🛡️ Inspector',
      );
    } else {
      _universalLog(
        "${_I18n.t('sentinel_active')}. ${_I18n.t('monitoring_on')}",
        name: '🛡️ Inspector',
      );
    }

    // 2. Forced Initial Save
    instance._isDataDirty = true; 
    await instance._saveSnapshotReport();

    // 3. Global Exception Listener
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
         final route = instance._currentRoute;
         final errorMsg = "🚨 [${_I18n.t('overflow')}] Device: ${instance._deviceInfo} | Route: $route | Location: ${details.library} | Detail: ${details.exception.toString().split('\n').first}";
         _universalLog(errorMsg, name: '🚨 ALARM', level: 2000);
         instance._recordError(errorMsg);
      }
      FlutterError.presentError(details);
    };

    // 4. Mode-Based Saving Strategy
    if (!autoTest) {
      // If NOT in auto-test (Monitoring only), use periodic auto-save
      instance._startAutoSaveTimer();
    } else {
      // If in AUTO-TEST, we exclusively save at the end (_finishAudit)
      _universalLog("💡 ${_I18n.t('robot_on')} - Reporting will be generated at the end.", name: '🤖 Inspector');
      Timer(const Duration(seconds: 4), () {
        instance.startAutoPilot();
      });
    }
  }

  /// Internal Universal Logger (Multi-Channel Output)
  static void _universalLog(String message, {String name = 'Inspector', int level = 0}) {
    dev.log(message, name: name, level: level);
    final timeStr = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    debugPrint("[$timeStr] [$name] $message");
  }

  void _startAutoSaveTimer() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isDataDirty && !_isAutoPilotRunning) {
        _saveSnapshotReport();
      }
    });
  }

  Future<void> _saveSnapshotReport() async {
    _isDataDirty = false;
    try {
      final reportContent = _generateReportString();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/inspector_report.txt');
      await file.writeAsString(reportContent);
      
      if (kDebugMode) {
        _universalLog("💾 [${_I18n.t('snapshot')}] ${_I18n.t('state_synced')}: ${file.path}", name: '📄 File');
      } else {
        dev.log("💾 [${_I18n.t('snapshot')}] ${_I18n.t('state_synced')}.", name: '📄 File');
      }
    } catch (e) {
      // Silent error
    }
  }

  String _generateReportString() {
    StringBuffer report = StringBuffer();
    report.writeln("${_I18n.t('time')}: ${DateTime.now()}");
    report.writeln("${_I18n.t('device_details')}: $_deviceInfo");
    report.writeln("${_I18n.t('depth')}: $_maxClicks");
    
    final totalPaths = _interactionStats.length;
    final fullyCovered = _interactionStats.values.where((v) => v >= _maxClicks).length;

    report.writeln("\n[1. ${_I18n.t('stat_title')}]");
    report.writeln("${_I18n.t('total_paths')}: $totalPaths");
    report.writeln("${_I18n.t('covered_paths')}: $fullyCovered");
    report.writeln("${_I18n.t('completion')}: ${(totalPaths > 0 ? (fullyCovered / totalPaths * 100) : 0).toStringAsFixed(1)}%");

    report.writeln("\n[2. ${_I18n.t('path_details')}]");
    if (_interactionStats.isEmpty) {
      report.writeln("- ${_I18n.t('no_action')}");
    } else {
      _interactionStats.forEach((key, value) {
        final status = value >= _maxClicks ? "✅ ${_I18n.t('covered')}" : "⏳ ${_I18n.t('incomplete')}";
        report.writeln("- ${_I18n.t('path')}: $key | ${_I18n.t('count')}: $value/$_maxClicks | ${_I18n.t('status')}: $status");
      });
    }
    
    report.writeln("\n[3. ${_I18n.t('error_title')}]");
    if (_errorLog.isEmpty) {
      report.writeln("✨ ${_I18n.t('perfect')}");
    } else {
      for (var err in _errorLog) {
        report.writeln(err);
      }
    }
    
    return report.toString();
  }

  Future<String> _fetchDeviceInfo() async {
    try {
      String model = "Unknown Device";
      String os = Platform.operatingSystem;
      String version = Platform.operatingSystemVersion;
      
      // Heuristically find model name in env
      final envModel = Platform.environment['SIMULATOR_MODEL_IDENTIFIER'] ?? 
                      Platform.environment['DEVICE_NAME'];
      
      if (envModel != null && envModel.isNotEmpty) {
        model = envModel;
      } else if (Platform.isIOS || Platform.isAndroid) {
          model = Platform.isIOS ? "iOS Device" : "Android Device";
      }

      return "$model ($os $version)";
    } catch (e) {
      return "Generic Device (${Platform.operatingSystem})";
    }
  }

  void startAutoPilot() {
    if (_isAutoPilotRunning) return;
    _isAutoPilotRunning = true;
    _universalLog("${_I18n.t('robot_on')} Mode: Auditing.", name: '🤖 Inspector', level: 500);
    _robotLoop();
  }

  void _recordError(String msg) {
    if (!_errorLog.contains(msg)) {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = "[$timestamp] $msg";
      _errorLog.add(logEntry);
      _isDataDirty = true; 
      _appendErrorToFile(logEntry);
    }
  }

  Future<void> _appendErrorToFile(String entry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/inspector_error_history.log');
      await file.writeAsString("$entry\n", mode: FileMode.append);
    } catch (e) {
      _universalLog("⚠️ ${_I18n.t('report_fail')}: $e", name: '⚠️ FileError');
    }
  }

  Future<void> _robotLoop() async {
    while (_isAutoPilotRunning) {
      await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(800)));
      try {
        final elementInfo = _findOptimalElement();
        if (elementInfo != null) {
          final element = elementInfo.item1;
          final name = elementInfo.item2;
          final viewName = _findNearestView(element);
          
          final entryKey = "$_currentRoute > $name";
          _interactionStats[entryKey] = (_interactionStats[entryKey] ?? 0) + 1;
          _clickHistory.insert(0, element.hashCode);
          if (_clickHistory.length > 5) _clickHistory.removeLast();

          _isDataDirty = true; 
          _universalLog(
            "👉 ${_I18n.t('auditing')}: [$_currentRoute] | $name | View: $viewName | ${_I18n.t('progress')}: ${_interactionStats[entryKey]}/$_maxClicks",
            name: '👉 Robot',
          );
          _performTap(element);
        } else {
          _checkAndFinish();
        }
      } catch (e) {
        // Silent
      }
    }
  }

  void _checkAndFinish() {
    if (_interactionStats.isEmpty) return;
    _noActionCount++;
    if (_noActionCount > 8) {
       _finishAudit();
    }
  }
  int _noActionCount = 0;

  Tuple2<Element, String>? _findOptimalElement() {
    List<Tuple2<Element, String>> candidates = [];
    void visitor(Element element) {
      final widget = element.widget;
      bool isInteractable = widget is InkWell || widget is GestureDetector || widget is ElevatedButton || widget is TextButton || widget is IconButton;
      if (isInteractable) {
        final RenderObject? renderObject = element.renderObject;
        if (renderObject is RenderBox && renderObject.hasSize && renderObject.size.height > 10) {
          String name = _extractNameFromElement(element);
          final entryKey = "$_currentRoute > $name";
          int clickCount = _interactionStats[entryKey] ?? 0;
          if (clickCount < _maxClicks && !_clickHistory.contains(element.hashCode)) {
            candidates.add(Tuple2(element, name));
          }
        }
      }
      element.visitChildren(visitor);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    if (candidates.isEmpty) return null;
    _noActionCount = 0;
    candidates.sort((a, b) => (_interactionStats["$_currentRoute > ${a.item2}"] ?? 0).compareTo(_interactionStats["$_currentRoute > ${b.item2}"] ?? 0));
    return candidates.first;
  }

  String _findNearestView(Element element) {
    String found = "UnknownView";
    element.visitAncestorElements((ancestor) {
      final type = ancestor.widget.runtimeType.toString();
      if (type.endsWith('View') || type.endsWith('Page') || type.endsWith('Screen')) {
        found = type;
        return false; 
      }
      return true;
    });
    return found;
  }

  String _extractNameFromElement(Element element) {
    String foundName = "";
    void textVisitor(Element el) {
      if (foundName.isNotEmpty) return;
      if (el.widget is Text) {
        foundName = (el.widget as Text).data ?? "";
      } else if (el.widget is Icon) {
        foundName = "Icon_${(el.widget as Icon).icon?.toString().split('.').last ?? 'unknown'}";
      }
      el.visitChildren(textVisitor);
    }
    element.visitChildren(textVisitor);
    return foundName.isEmpty ? "Widget_${element.widget.runtimeType}" : foundName;
  }

  void _performTap(Element element) {
    final widget = element.widget;
    if (widget is InkWell) widget.onTap?.call();
    else if (widget is GestureDetector) widget.onTap?.call();
    else if (widget is ElevatedButton) widget.onPressed?.call();
    else if (widget is TextButton) widget.onPressed?.call();
    else if (widget is IconButton) widget.onPressed?.call();
  }

  Future<void> _finishAudit() async {
    if (!_isAutoPilotRunning) return;
    _isAutoPilotRunning = false;
    _isDataDirty = true;
    await _saveSnapshotReport();
    _universalLog("📋 ${_I18n.t('audit_done')}.", name: '📋 Report', level: 800);
  }

  void _updateRoute(String? name) {
    if (name != null && name != _currentRoute) {
      _currentRoute = name;
      _isDataDirty = true; 
      _universalLog("${_I18n.t('route_change')}: [$_currentRoute]", name: '📍 Route');
    }
  }
}

class _InspectorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FlutterInspector()._updateRoute(route.settings.name);
  }
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FlutterInspector()._updateRoute(previousRoute?.settings.name);
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  const Tuple2(this.item1, this.item2);
}

class _I18n {
  static String get lang => ui.PlatformDispatcher.instance.locale.languageCode;
  static final Map<String, Map<String, String>> _data = {
    'en': {
      'sentinel_active': 'Sentinel Active',
      'monitoring_on': 'Monitoring UI exceptions...',
      'overflow': 'UI Overflow',
      'snapshot': 'Snapshot',
      'state_synced': 'System state synced',
      'time': 'Time',
      'device_details': 'Device Details',
      'depth': 'Audit Depth',
      'stat_title': 'Audit Statistics Summary',
      'total_paths': 'Total Discovered Paths',
      'covered_paths': 'Fully Covered Paths',
      'completion': 'Completion Rate',
      'path_details': 'Detailed Path Records',
      'no_action': 'No click actions performed.',
      'path': 'Path',
      'count': 'Count',
      'status': 'Status',
      'covered': 'Covered',
      'incomplete': 'Incomplete',
      'error_title': 'UI Exceptions (Snapshot)',
      'perfect': 'Perfect! No overflow or crash detected in this session.',
      'robot_on': 'Robot online.',
      'auditing': 'Auditing',
      'progress': 'Progress',
      'audit_done': 'Audit Task Completed',
      'route_change': 'Route switched',
      'report_fail': 'Failed to save log',
    },
    'zh': {
      'sentinel_active': '巡检系统已激活',
      'monitoring_on': '正在实时监测 UI 异常...',
      'overflow': 'UI 越界',
      'snapshot': '快照',
      'state_synced': '系统状态已同步',
      'time': '时间',
      'device_details': '设备详情',
      'depth': '审计深度',
      'stat_title': '审计统计摘要',
      'total_paths': '总侦测路径数',
      'covered_paths': '已覆盖路径数',
      'completion': '完成率',
      'path_details': '详细路径记录',
      'no_action': '未执行任何点击动作。',
      'path': '路径',
      'count': '次数',
      'status': '状态',
      'covered': '已覆盖',
      'incomplete': '未完成',
      'error_title': 'UI 异常记录 (快照)',
      'perfect': '完美！本次会话未检测到越界或崩溃。',
      'robot_on': '巡航机器人上线。',
      'auditing': '正在审计',
      'progress': '进度',
      'audit_done': '巡检任务已完成',
      'route_change': '路由切换',
      'report_fail': '记录保存失败',
    }
  };
  static String t(String key) {
    final languageCode = lang;
    final localeData = _data[languageCode] ?? _data['en']!;
    return localeData[key] ?? key;
  }
}
