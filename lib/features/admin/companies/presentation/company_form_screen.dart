import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/company_domain_warning_banner.dart';
import '../../../../data/models/company.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../core/errors/app_exception.dart';

class CompanyFormScreen extends ConsumerStatefulWidget {
  const CompanyFormScreen({super.key, this.initialCompany});

  final Company? initialCompany;

  @override
  ConsumerState<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends ConsumerState<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _domainController;
  late final TextEditingController _websiteController;
  late final TextEditingController _careerPageUrlController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _descriptionController;

  SourceType _selectedSourceType = SourceType.greenhouse;

  bool _isSubmitting = false;
  bool _domainOrCareerUrlDirty = false;
  String? _serverError;

  bool get _isEditMode => widget.initialCompany != null;

  static const _domainRegex =
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$';

  @override
  void initState() {
    super.initState();
    final c = widget.initialCompany;
    _nameController = TextEditingController(text: c?.name ?? '');
    _domainController = TextEditingController(text: c?.slug ?? '');
    _websiteController = TextEditingController(text: c?.website ?? '');
    _careerPageUrlController = TextEditingController(text: c?.careersUrl ?? '');
    _logoUrlController = TextEditingController(text: c?.logoUrl ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    if (c != null && c.sources.isNotEmpty) {
      _selectedSourceType = c.sources.first.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _websiteController.dispose();
    _careerPageUrlController.dispose();
    _logoUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company name is required.';
    }
    return null;
  }

  String? _validateDomain(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Domain is required.';
    }
    final regex = RegExp(_domainRegex);
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid domain (e.g. example.com).';
    }
    return null;
  }

  String? _validateCareerPageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority) {
      return 'Enter a valid URL.';
    }
    final domain = _domainController.text.trim();
    if (domain.isNotEmpty && !uri.host.endsWith(domain)) {
      return 'Career page URL host must end with the domain ($domain).';
    }
    return null;
  }

  String? _validateWebsite(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAbsolutePath ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid http/https URL.';
    }
    return null;
  }

  void _onDomainOrCareerUrlChanged() {
    if (!_isEditMode) return;
    final initial = widget.initialCompany!;
    final domainChanged = _domainController.text != (initial.slug ?? '');
    final careerChanged =
        _careerPageUrlController.text != (initial.careersUrl ?? '');
    final dirty = domainChanged || careerChanged;
    if (dirty != _domainOrCareerUrlDirty) {
      setState(() => _domainOrCareerUrlDirty = dirty);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'domain': _domainController.text.trim(),
        'website': _websiteController.text.trim(),
        'careersUrl': _careerPageUrlController.text.trim(),
        'logoUrl': _logoUrlController.text.trim(),
        'description': _descriptionController.text.trim(),
        'sourceType': _selectedSourceType.name,
      };

      if (_isEditMode) {
        data['id'] = widget.initialCompany!.id;
      } else {
        data['collectionEnabled'] = false;
      }

      await ref.read(adminRepositoryProvider).upsertCompany(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company saved.')),
        );
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      final isDuplicate = e.message.contains('DUPLICATE_DOMAIN') ||
          (e.code == 'already-exists');
      setState(() {
        _serverError = isDuplicate
            ? 'A company with this domain already exists. Please check the existing entry.'
            : e.message;
      });
    } catch (e) {
      setState(() {
        _serverError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _isEditMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Company' : 'Add Company'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Domain-change warning (edit mode only)
            if (isEdit && _domainOrCareerUrlDirty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CompanyDomainWarningBanner(
                  message:
                      'Changing the domain or career page URL will disable job collection until admin re-verification.',
                ),
              ),

            // Server error banner
            if (_serverError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CompanyDomainWarningBanner(message: _serverError!),
              ),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                hintText: 'Acme Corp',
              ),
              validator: _validateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Domain
            TextFormField(
              controller: _domainController,
              decoration: const InputDecoration(
                labelText: 'Domain *',
                hintText: 'acme.com',
              ),
              validator: _validateDomain,
              onChanged: (_) => _onDomainOrCareerUrlChanged(),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Website
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://acme.com',
              ),
              validator: _validateWebsite,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Career Page URL
            TextFormField(
              controller: _careerPageUrlController,
              decoration: const InputDecoration(
                labelText: 'Career Page URL',
                hintText: 'https://careers.acme.com',
              ),
              validator: _validateCareerPageUrl,
              onChanged: (_) => _onDomainOrCareerUrlChanged(),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Logo URL
            TextFormField(
              controller: _logoUrlController,
              decoration: const InputDecoration(
                labelText: 'Logo URL',
                hintText: 'https://cdn.example.com/logo.png',
              ),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Short description of the company…',
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 12),

            // Source Type
            DropdownButtonFormField<SourceType>(
              initialValue: _selectedSourceType,
              decoration: const InputDecoration(labelText: 'Source Type'),
              items: const [
                DropdownMenuItem(
                  value: SourceType.greenhouse,
                  child: Text('Greenhouse'),
                ),
                DropdownMenuItem(
                  value: SourceType.lever,
                  child: Text('Lever'),
                ),
                DropdownMenuItem(
                  value: SourceType.smartrecruiters,
                  child: Text('SmartRecruiters'),
                ),
                DropdownMenuItem(
                  value: SourceType.officialFeed,
                  child: Text('Official Feed'),
                ),
                DropdownMenuItem(
                  value: SourceType.careersPage,
                  child: Text('Careers Page'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSourceType = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Update Company' : 'Create Company'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
