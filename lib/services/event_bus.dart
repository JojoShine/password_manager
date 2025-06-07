import 'dart:async';

/// 事件总线服务
/// 用于在应用内不同组件之间传递事件，特别是在保存密码后通知UI刷新
class EventBus {
  static final EventBus _instance = EventBus._internal();
  static EventBus get instance => _instance;

  EventBus._internal();

  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  /// 获取事件流
  Stream<AppEvent> get events => _controller.stream;

  /// 发送事件
  void emit(AppEvent event) {
    _controller.add(event);
  }

  /// 发送密码数据变更事件
  void emitPasswordDataChanged() {
    emit(PasswordDataChangedEvent());
  }

  /// 释放资源
  void dispose() {
    _controller.close();
  }
}

/// 应用事件基类
abstract class AppEvent {}

/// 密码数据变更事件
/// 当密码被保存、更新或删除时触发
class PasswordDataChangedEvent extends AppEvent {
  final DateTime timestamp = DateTime.now();

  @override
  String toString() => 'PasswordDataChangedEvent(timestamp: $timestamp)';
}
