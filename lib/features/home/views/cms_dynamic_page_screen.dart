import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/cms_page_model.dart';

/// صفحة محتوى ديناميكي من GET /pages/{slug}.
class CmsDynamicPageScreen extends StatefulWidget {
  const CmsDynamicPageScreen({
    super.key,
    required this.slug,
    this.token,
    required this.fallbackTitle,
  });

  final String slug;
  final String? token;
  final String fallbackTitle;

  @override
  State<CmsDynamicPageScreen> createState() => _CmsDynamicPageScreenState();
}

class _CmsDynamicPageScreenState extends State<CmsDynamicPageScreen> {
  final HomeRepository _repository = HomeRepository();
  CmsPage? _page;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.getCmsPage(
        token: widget.token,
        slug: widget.slug,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _errorMessage(Object e) {
    if (e is HomeApiException) return e.message;
    return 'profile.pageLoadError'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final title = _page?.title.trim().isNotEmpty == true
        ? _page!.title
        : widget.fallbackTitle;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage(_error!),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: Text('offline.retry'.tr),
              ),
            ],
          ),
        ),
      );
    }
    final page = _page;
    if (page == null) {
      return Center(child: Text('profile.pageLoadError'.tr));
    }

    final updated = _formatUpdatedAt(page.updatedAt);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: SelectableText(
              page.content.trim().isEmpty
                  ? 'profile.pageEmptyContent'.tr
                  : page.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: cs.onSurface,
              ),
            ),
          ),
          if (updated != null) ...[
            const SizedBox(height: 12),
            Text(
              'profile.pageLastUpdated'.trParams({'date': updated}),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _formatUpdatedAt(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
