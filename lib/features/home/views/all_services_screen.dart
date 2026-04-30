import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_card.dart';

class AllServicesScreen extends StatelessWidget {
  final List<ServiceModel> services;
  final int? selectedServiceId;
  final ValueChanged<ServiceModel> onServiceTap;

  const AllServicesScreen({
    super.key,
    required this.services,
    required this.selectedServiceId,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'home.ourServices'.tr,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: services.isEmpty
            ? Center(
                child: Text(
                  'home.noServices'.tr,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: services.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.93,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, index) {
                  final service = services[index];
                  return HomeServiceCard(
                    title: service.name,
                    imageUrl: service.icon,
                    selected: selectedServiceId == service.id,
                    onTap: () => onServiceTap(service),
                  );
                },
              ),
      ),
    );
  }
}

