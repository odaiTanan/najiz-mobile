import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppSupportFloatingButton extends StatelessWidget {
  const WhatsAppSupportFloatingButton({super.key});

  static const String _supportPhone = '+963961102030';

  static const String _whatsAppSvg = '''
<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
<path fill="#ffffff" d="M19.11 17.37c-.27-.14-1.59-.78-1.84-.87-.25-.09-.43-.14-.61.14-.18.27-.7.87-.86 1.05-.16.18-.32.2-.59.07-.27-.14-1.15-.42-2.19-1.35-.81-.72-1.36-1.61-1.52-1.88-.16-.27-.02-.42.12-.55.12-.12.27-.32.41-.48.14-.16.18-.27.27-.46.09-.18.05-.34-.02-.48-.07-.14-.61-1.47-.84-2.01-.22-.53-.45-.46-.61-.47h-.52c-.18 0-.48.07-.73.34-.25.27-.95.93-.95 2.26s.98 2.62 1.11 2.8c.14.18 1.92 2.93 4.65 4.11.65.28 1.16.45 1.55.57.65.21 1.24.18 1.71.11.52-.08 1.59-.65 1.82-1.28.23-.63.23-1.17.16-1.28-.07-.11-.25-.18-.52-.32zM16.03 4.8c-6.18 0-11.2 5-11.2 11.17 0 1.97.52 3.9 1.5 5.6L4.74 27.4l5.97-1.56a11.2 11.2 0 0 0 5.31 1.35h.01c6.18 0 11.2-5 11.2-11.17A11.18 11.18 0 0 0 16.03 4.8zm0 20.5h-.01a9.3 9.3 0 0 1-4.74-1.3l-.34-.2-3.54.93.95-3.45-.22-.35a9.25 9.25 0 0 1-1.42-4.96c0-5.13 4.18-9.3 9.32-9.3 2.49 0 4.83.97 6.59 2.73a9.22 9.22 0 0 1 2.73 6.58c0 5.13-4.18 9.31-9.32 9.31z"/>
</svg>
''';

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _buildMessage({required String issue}) {
    if (!Get.isRegistered<HomeController>()) {
      return 'مرحباً، أحتاج مساعدة من خدمة عملاء ناجز.\n'
          'المشكلة: $issue';
    }

    final controller = Get.find<HomeController>();
    final name = controller.displayName.value.trim();
    final order = controller.primaryActiveOrder;
    final orderNumber = order?.orderNumber.trim() ?? '';
    final vendorName = order?.vendor?.name.trim() ?? '';

    final buffer = StringBuffer();

    buffer.writeln('مرحباً، أحتاج مساعدة من خدمة عملاء ناجز.');

    if (name.isNotEmpty) {
      buffer.writeln('الاسم: $name');
    }

    if (orderNumber.isNotEmpty) {
      buffer.write('آخر طلب: $orderNumber');

      if (vendorName.isNotEmpty) {
        buffer.write(' - $vendorName');
      }

      buffer.writeln();
    }

    buffer.writeln('المشكلة: $issue');
    buffer.write('يرجى مساعدتي بخصوص هذا الطلب.');

    return buffer.toString();
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: _supportPhone);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWhatsApp({required String issue}) async {
    final phone = _digitsOnly(_supportPhone);
    final message = Uri.encodeComponent(_buildMessage(issue: issue));

    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showActions(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    final homeController = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : null;

    final order = homeController?.primaryActiveOrder;
    final orderNumber = order?.orderNumber.trim() ?? '';
    final vendorName = order?.vendor?.name.trim() ?? '';

    const issues = <String>[
      'الطلب وصل متأخر',
      'الطلب ناقص',
      'الطلب وصل بارد',
      'مشكلة بالدفع',
      'مشكلة مع السائق أو المندوب',
      'مشكلة أخرى',
    ];

    String? selectedIssue;
    final customIssueController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final customIssue = customIssueController.text.trim();

            final resolvedIssue = selectedIssue == 'مشكلة أخرى'
                ? customIssue
                : selectedIssue ?? '';

            final canOpenWhatsApp = resolvedIssue.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إذا عندك مشكلة، تواصل معنا',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أهلاً وسهلاً بك، خدمة عملاء ناجز بخدمتك على مدار 24 ساعة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),

                    if (orderNumber.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أنت تتواصل معنا بخصوص آخر طلب لديك',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              vendorName.isEmpty
                                  ? 'الطلب $orderNumber'
                                  : 'الطلب $orderNumber • $vendorName',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Text(
                      'ما المشكلة التي واجهتك؟',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: issues.map((issue) {
                        final selected = selectedIssue == issue;

                        return ChoiceChip(
                          label: Text(issue),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedIssue = issue;

                              if (issue != 'مشكلة أخرى') {
                                customIssueController.clear();
                              }
                            });
                          },
                          selectedColor: const Color(
                            0xFF25D366,
                          ).withValues(alpha: 0.16),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF25D366)
                                : cs.outlineVariant,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? const Color(0xFF128C4A)
                                : cs.onSurface,
                          ),
                        );
                      }).toList(),
                    ),

                    if (selectedIssue == 'مشكلة أخرى') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customIssueController,
                        maxLines: 3,
                        minLines: 2,
                        onChanged: (_) {
                          setSheetState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'اكتب المشكلة التي واجهتك...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'نحن بخدمتك 24 ساعة يومياً، وسنعمل على مساعدتك بأسرع وقت ممكن.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await _call();
                            },
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('اتصال'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canOpenWhatsApp
                                ? () async {
                                    Navigator.pop(sheetContext);

                                    await _openWhatsApp(issue: resolvedIssue);
                                  }
                                : null,
                            icon: SvgPicture.string(
                              _whatsAppSvg,
                              width: 21,
                              height: 21,
                            ),
                            label: const Text('واتساب'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  cs.surfaceContainerHighest,
                              disabledForegroundColor: cs.onSurfaceVariant,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!canOpenWhatsApp) ...[
                      const SizedBox(height: 8),
                      Text(
                        'اختر نوع المشكلة أولاً للمتابعة عبر واتساب.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    customIssueController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 16,
      bottom: 16,
      child: SafeArea(
        child: Material(
          elevation: 7,
          color: const Color(0xFF25D366),
          shadowColor: Colors.black26,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showActions(context),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Center(
                child: SvgPicture.string(_whatsAppSvg, width: 31, height: 31),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
