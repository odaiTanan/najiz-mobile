import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

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
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (_, index) {
                  final service = services[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth;
                      return InkWell(
                        onTap: () => onServiceTap(service),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: side,
                              height: side,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cs.outlineVariant,
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 7,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: NetworkImageWithFallback(
                                    url: service.icon,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              service.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
