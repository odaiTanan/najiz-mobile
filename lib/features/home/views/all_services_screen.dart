import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_tile.dart';

class AllServicesScreen extends StatelessWidget {
  final List<ServiceModel> services;
  final ValueChanged<ServiceModel> onServiceTap;

  const AllServicesScreen({
    super.key,
    required this.services,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: cs.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'home.ourServices'.tr,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: services.isEmpty
            ? Center(
                child: Text(
                  'home.noServices'.tr,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                itemCount: services.length,
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (_, index) {
                  final service = services[index];
                  return HomeServiceTile(
                    service: service,
                    layout: HomeServiceTileLayout.grid,
                    onTap: () => onServiceTap(service),
                  );
                },
              ),
      ),
    );
  }
}
