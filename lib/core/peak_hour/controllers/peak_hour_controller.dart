import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/peak_hour/models/peak_hour_status.dart';
import 'package:najiz_go_express/core/peak_hour/repositories/peak_hour_repository.dart';
import 'package:najiz_go_express/core/peak_hour/services/peak_hour_dependencies.dart';
import 'package:najiz_go_express/core/services/session_service.dart';

class PeakHourController extends GetxController with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 3);

  final PeakHourRepository _repository = resolvePeakHourRepository();
  final status = Rxn<PeakHourStatus>();
  final isRefreshing = false.obs;

  Timer? _refreshTimer;

  bool get isPeakHourActive => status.value?.isPeakHourActive == true;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  Future<void> ensureFreshStatus() {
    if (status.value == null && !isRefreshing.value) {
      return refresh();
    }
    return Future<void>.value();
  }

  @override
  Future<void> refresh() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    try {
      final token = await SessionService.getToken();
      final next = await _repository.getPeakHourStatus(token: token);
      status.value = next;
    } catch (_) {
      status.value = const PeakHourStatus(isPeakHour: false, enabled: false);
    } finally {
      isRefreshing.value = false;
    }
  }
}
