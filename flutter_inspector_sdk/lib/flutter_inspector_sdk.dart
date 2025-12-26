import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

/// 🚀 Flutter Inspector SDK (Ultimate Clean Log Edition)
/// 增强功能：修复 ANSI 乱码、多语言支持、实时记录、本地报告
class FlutterInspector {
  static final FlutterInspector _instance = FlutterInspector._internal();
  factory FlutterInspector() => _instance;
  FlutterInspector._internal();

  bool _isAutoPilotRunning = false;
  final _random = Random();
  
  final Map<String, int> _interactionStats = {}; 
  final List<String> _errorLog = [];
  final List<int> _clickHistory = []; 
  
  String _currentRoute = "Initial";
  int _maxClicks = 2; 

  static final NavigatorObserver observer = _InspectorObserver();

  /// 初始化巡检插件
  static Future<void> init({
    bool autoStart = true, 
    int maxClicks = 2,
  }) async {
    if (!kDebugMode) return; 
    
    FlutterInspector()._maxClicks = maxClicks;
    debugPrint("🛡️ [Inspector SDK] ${_I18n.t('init_success')} ${_I18n.t('depth')}: $maxClicks. ${_I18n.t('mode_on')}");
    
    if (autoStart) {
      Timer(const Duration(seconds: 4), () {
        FlutterInspector().startAutoPilot();
      });
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
         final route = FlutterInspector()._currentRoute;
         final errorMsg = "🚨 [${_I18n.t('overflow')}] ${_I18n.t('route')}: $route, ${_I18n.t('location')}: ${details.library}, ${_I18n.t('detail')}: ${details.exception.toString().split('\n').first}";
         debugPrint("\n$errorMsg");
         FlutterInspector()._recordError(errorMsg);
      }
      FlutterError.presentError(details);
    };
  }

  void startAutoPilot() {
    if (_isAutoPilotRunning) return;
    _isAutoPilotRunning = true;
    debugPrint("🤖 [Inspector SDK] ${_I18n.t('robot_on')} ${_I18n.t('tracking')}: [$_currentRoute]");
    _robotLoop();
  }

  void _recordError(String msg) {
    if (!_errorLog.contains(msg)) {
      _errorLog.add("${DateTime.now()}: $msg");
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

          debugPrint("👉 [Robot] ${_I18n.t('auditing')}: [$_currentRoute] | $name | View: $viewName | ${_I18n.t('progress')}: ${_interactionStats[entryKey]}/$_maxClicks");
          _performTap(element);
        } else {
          _checkAndFinish();
        }
      } catch (e) {
        // Silent
      }
    }
  }

  int _noActionCount = 0;
  void _checkAndFinish() {
    _noActionCount++;
    if (_noActionCount > 5) {
       _finishAudit();
    }
  }

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
    
    final reportTitle = "======= 🏆 ${_I18n.t('audit_done')} 🏆 =======";
    final reportContent = _generateReportString();
    
    debugPrint("\n$reportTitle");
    debugPrint(reportContent);
    debugPrint("${"=" * reportTitle.length}\n");
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/inspector_report.txt');
      await file.writeAsString(reportContent);
      debugPrint("📍 ${_I18n.t('report_saved')}: ${file.path}");
      debugPrint("🚀 ${_I18n.t('audit_finish_hint')}");
    } catch (e) {
      debugPrint("⚠️ ${_I18n.t('report_fail')}");
    }
  }

  String _generateReportString() {
    StringBuffer report = StringBuffer();
    report.writeln("${_I18n.t('time')}: ${DateTime.now()}");
    report.writeln("${_I18n.t('depth')}: $_maxClicks");
    
    report.writeln("\n[1. ${_I18n.t('stat_title')}]");
    if (_interactionStats.isEmpty) {
      report.writeln("- ${_I18n.t('no_action')}");
    } else {
      _interactionStats.forEach((key, value) {
        final status = value >= _maxClicks ? "✅ ${_I18n.t('covered')}" : "⏳ ${_I18n.t('incomplete')}";
        report.writeln("- ${_I18n.t('path')}: $key | ${_I18n.t('count')}: $value/$_maxClicks | ${_I18n.t('status')}: $status");
      });
    }
    
    report.writeln("\n[2. ${_I18n.t('error_title')}]");
    if (_errorLog.isEmpty) {
      report.writeln("✨ ${_I18n.t('perfect')}");
    } else {
      for (var err in _errorLog) {
        report.writeln(err);
      }
    }
    
    report.writeln("\n[${_I18n.t('conclusion')}]");
    int totalFeatures = _interactionStats.length;
    int coveredFeatures = _interactionStats.values.where((v) => v >= _maxClicks).length;
    report.writeln("${_I18n.t('completion')}: ${(totalFeatures > 0 ? (coveredFeatures / totalFeatures * 100) : 0).toStringAsFixed(1)}%");
    return report.toString();
  }

  void _updateRoute(String? name) {
    if (name != null && name != _currentRoute) {
      _currentRoute = name;
      debugPrint("📍 [Inspector SDK] ${_I18n.t('route_change')}: $_currentRoute");
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

class _I18n {
  static String get lang => ui.PlatformDispatcher.instance.locale.languageCode;
  static final Map<String, Map<String, String>> _data = {
    'en': {
      'init_success': 'Initialized successfully.', 'depth': 'Audit Depth', 'mode_on': 'Entering full path...',
      'robot_on': 'Robot online.', 'tracking': 'Path tracking', 'overflow': 'UI Overflow', 'route': 'Route',
      'location': 'Location', 'detail': 'Detail', 'auditing': 'Auditing', 'feature': 'Feature', 'progress': 'Progress',
      'audit_done': 'Audit Task Completed', 'report_saved': 'Report saved at', 'audit_finish_hint': 'Audit finished! Check logs.',
      'report_fail': 'Report writing failed.', 'time': 'Time', 'stat_title': 'Audit Stats', 'no_action': 'No action.',
      'path': 'Path', 'count': 'Count', 'status': 'Status', 'covered': 'Covered', 'incomplete': 'Incomplete',
      'error_title': 'Exceptions', 'perfect': 'Perfect! No issues.', 'conclusion': 'Conclusion', 'completion': 'Completion Rate',
      'route_change': 'Route switched',
    },
    'zh': {
      'init_success': '初始化成功。', 'depth': '审计深度', 'mode_on': '开始全路径探测...',
      'robot_on': '巡航机器人上线。', 'tracking': '当前路径', 'overflow': 'UI 越界', 'route': '路由',
      'location': '定位', 'detail': '详情', 'auditing': '正在审计', 'feature': '功能点', 'progress': '进度',
      'audit_done': '巡检任务圆满完成', 'report_saved': '报告已保存在', 'audit_finish_hint': '审计结束！请核对日志结果。',
      'report_fail': '报告写入失败。', 'time': '时间', 'stat_title': '审计统计', 'no_action': '无点击。',
      'path': '路径', 'count': '次数', 'status': '状态', 'covered': '已覆盖', 'incomplete': '未完成',
      'error_title': '异常记录', 'perfect': '完美！未检测到错误。', 'conclusion': '结论', 'completion': '完成度',
      'route_change': '路由切换',
    }
  };
  static String t(String key) {
    final languageCode = lang;
    final localeData = _data[languageCode] ?? _data['en']!;
    return localeData[key] ?? key;
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  const Tuple2(this.item1, this.item2);
}
