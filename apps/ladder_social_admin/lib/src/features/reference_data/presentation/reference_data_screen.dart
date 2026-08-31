import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

enum _ReferenceSection { countries, cities, taskCategories, recurrenceTypes }

final class ReferenceDataScreen extends ConsumerStatefulWidget {
  const ReferenceDataScreen({super.key});

  @override
  ConsumerState<ReferenceDataScreen> createState() => _ReferenceDataScreenState();
}

final class _ReferenceDataScreenState extends ConsumerState<ReferenceDataScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ReferenceSection _section = _ReferenceSection.countries;
  bool? _isActive;
  Future<PagedResult<dynamic>>? _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _resource => switch (_section) {
        _ReferenceSection.countries => 'countries',
        _ReferenceSection.cities => 'cities',
        _ReferenceSection.taskCategories => 'task-categories',
        _ReferenceSection.recurrenceTypes => 'recurrence-types',
      };

  String get _title => switch (_section) {
        _ReferenceSection.countries => 'Countries',
        _ReferenceSection.cities => 'Cities',
        _ReferenceSection.taskCategories => 'Task categories',
        _ReferenceSection.recurrenceTypes => 'Recurrence types',
      };

  void _load({int? page}) {
    final int target = page ?? _page;
    final AdminRepository repository = ref.read(adminRepositoryProvider);
    Future<PagedResult<dynamic>> request;
    switch (_section) {
      case _ReferenceSection.countries:
        request = repository.getCountries(
          search: _searchController.text,
          isActive: _isActive,
          page: target,
        );
        break;
      case _ReferenceSection.cities:
        request = repository.getCities(
          search: _searchController.text,
          isActive: _isActive,
          page: target,
        );
        break;
      case _ReferenceSection.taskCategories:
        request = repository.getTaskCategories(
          search: _searchController.text,
          isActive: _isActive,
          page: target,
        );
        break;
      case _ReferenceSection.recurrenceTypes:
        request = repository.getRecurrenceTypes(
          search: _searchController.text,
          isActive: _isActive,
          page: target,
        );
        break;
    }
    setState(() {
      _page = target;
      _future = request;
    });
  }

  Future<void> _edit([dynamic item]) async {
    bool? changed;
    switch (_section) {
      case _ReferenceSection.countries:
        changed = await showDialog<bool>(
          context: context,
          builder: (_) => _CountryDialog(item: item as AdminCountry?),
        );
        break;
      case _ReferenceSection.cities:
        changed = await showDialog<bool>(
          context: context,
          builder: (_) => _CityDialog(item: item as AdminCity?),
        );
        break;
      case _ReferenceSection.taskCategories:
      case _ReferenceSection.recurrenceTypes:
        changed = await showDialog<bool>(
          context: context,
          builder: (_) => _ReferenceItemDialog(
            resource: _resource,
            title: _section == _ReferenceSection.taskCategories
                ? 'task category'
                : 'recurrence type',
            item: item as AdminReferenceItem?,
          ),
        );
        break;
    }
    if (changed == true && mounted) _load(page: 1);
  }

  Future<void> _deactivate(dynamic item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Deactivate item?'),
        content: const Text(
          'The item will no longer appear in new forms. Existing records remain valid.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final AdminRepository repository = ref.read(adminRepositoryProvider);
      switch (_section) {
        case _ReferenceSection.countries:
          await repository.deactivateCountry((item as AdminCountry).id);
          break;
        case _ReferenceSection.cities:
          await repository.deactivateCity((item as AdminCity).id);
          break;
        case _ReferenceSection.taskCategories:
        case _ReferenceSection.recurrenceTypes:
          await repository.deactivateReferenceItem(
            _resource,
            (item as AdminReferenceItem).id,
          );
          break;
      }
      if (mounted) {
        adminMessage(context, 'Reference item deactivated.');
        _load();
      }
    } catch (error) {
      if (mounted) adminMessage(context, ApiException.from(error).message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminPageHeader(
            title: 'Reference data',
            subtitle: 'Manage standardized values used by mobile and desktop forms.',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: Text('Add ${_title.toLowerCase().replaceAll(RegExp(r's$'), '')}'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<_ReferenceSection>(
            segments: const <ButtonSegment<_ReferenceSection>>[
              ButtonSegment(value: _ReferenceSection.countries, label: Text('Countries')),
              ButtonSegment(value: _ReferenceSection.cities, label: Text('Cities')),
              ButtonSegment(value: _ReferenceSection.taskCategories, label: Text('Categories')),
              ButtonSegment(value: _ReferenceSection.recurrenceTypes, label: Text('Recurrence')),
            ],
            selected: <_ReferenceSection>{_section},
            onSelectionChanged: (Set<_ReferenceSection> values) {
              setState(() {
                _section = values.first;
                _page = 1;
              });
              _load(page: 1);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search $_title',
                  leading: const Icon(Icons.search),
                  onSubmitted: (_) => _load(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _isActive,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const <DropdownMenuItem<bool?>>[
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: true, child: Text('Active')),
                    DropdownMenuItem(value: false, child: Text('Inactive')),
                  ],
                  onChanged: (bool? value) {
                    setState(() => _isActive = value);
                    _load(page: 1);
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<PagedResult<dynamic>>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<PagedResult<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return AdminErrorView(error: snapshot.error!, onRetry: _load);
                final PagedResult<dynamic> result = snapshot.data!;
                if (result.items.isEmpty) return Center(child: Text('No $_title match the current filters.'));
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: _columns(),
                            rows: result.items.map(_row).toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          onPressed: result.page > 1 ? () => _load(page: result.page - 1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page ${result.page} of ${result.totalPages == 0 ? 1 : result.totalPages} • ${result.totalCount} items'),
                        IconButton(
                          onPressed: result.page < result.totalPages ? () => _load(page: result.page + 1) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _columns() => switch (_section) {
        _ReferenceSection.countries => const <DataColumn>[
            DataColumn(label: Text('ISO')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
        _ReferenceSection.cities => const <DataColumn>[
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Country')),
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
        _ => const <DataColumn>[
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
      };

  DataRow _row(dynamic item) {
    final bool active = item.isActive as bool;
    final List<DataCell> cells;
    if (item is AdminCountry) {
      cells = <DataCell>[
        DataCell(Text(item.isoCode)),
        DataCell(Text(item.name)),
        DataCell(Text('${item.sortOrder}')),
        DataCell(Chip(label: Text(active ? 'Active' : 'Inactive'))),
        DataCell(_actions(item, active)),
      ];
    } else if (item is AdminCity) {
      cells = <DataCell>[
        DataCell(Text(item.name)),
        DataCell(Text(item.countryName)),
        DataCell(Text('${item.sortOrder}')),
        DataCell(Chip(label: Text(active ? 'Active' : 'Inactive'))),
        DataCell(_actions(item, active)),
      ];
    } else {
      final AdminReferenceItem value = item as AdminReferenceItem;
      cells = <DataCell>[
        DataCell(Text(value.code)),
        DataCell(Text(value.name)),
        DataCell(Text('${value.sortOrder}')),
        DataCell(Chip(label: Text(active ? 'Active' : 'Inactive'))),
        DataCell(_actions(item, active)),
      ];
    }
    return DataRow(cells: cells);
  }

  Widget _actions(dynamic item, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(onPressed: () => _edit(item), icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
        IconButton(
          onPressed: active ? () => _deactivate(item) : null,
          icon: const Icon(Icons.block_outlined),
          tooltip: active ? 'Deactivate' : 'Already inactive',
        ),
      ],
    );
  }
}

final class _CountryDialog extends ConsumerStatefulWidget {
  const _CountryDialog({this.item});
  final AdminCountry? item;

  @override
  ConsumerState<_CountryDialog> createState() => _CountryDialogState();
}

final class _CountryDialogState extends ConsumerState<_CountryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _order;
  bool _active = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name);
    _code = TextEditingController(text: widget.item?.isoCode);
    _order = TextEditingController(text: '${widget.item?.sortOrder ?? 0}');
    _active = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final AdminRepository repository = ref.read(adminRepositoryProvider);
      if (widget.item == null) {
        await repository.createCountry(name: _name.text, isoCode: _code.text, sortOrder: int.parse(_order.text));
      } else {
        await repository.updateCountry(AdminCountry(
          id: widget.item!.id,
          isoCode: _code.text.trim(),
          name: _name.text.trim(),
          isActive: _active,
          sortOrder: int.parse(_order.text),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Add country' : 'Edit country'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'ISO code'),
                  maxLength: 3,
                  validator: (String? value) => value == null || value.trim().length < 2 ? 'Enter a 2–3 character ISO code.' : null,
                ),
                TextFormField(controller: _order, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number, validator: _integer),
                if (widget.item != null)
                  SwitchListTile(value: _active, onChanged: (bool value) => setState(() => _active = value), title: const Text('Active')),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      );
}

final class _CityDialog extends ConsumerStatefulWidget {
  const _CityDialog({this.item});
  final AdminCity? item;

  @override
  ConsumerState<_CityDialog> createState() => _CityDialogState();
}

final class _CityDialogState extends ConsumerState<_CityDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _order;
  String? _countryId;
  bool _active = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name);
    _order = TextEditingController(text: '${widget.item?.sortOrder ?? 0}');
    _countryId = widget.item?.countryId;
    _active = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_countryId == null) return;
    setState(() => _saving = true);
    try {
      final AdminRepository repository = ref.read(adminRepositoryProvider);
      if (widget.item == null) {
        await repository.createCity(name: _name.text, countryId: _countryId!, sortOrder: int.parse(_order.text));
      } else {
        await repository.updateCity(AdminCity(
          id: widget.item!.id,
          name: _name.text.trim(),
          countryId: _countryId!,
          countryName: widget.item!.countryName,
          isActive: _active,
          sortOrder: int.parse(_order.text),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CountryItem>> countries = ref.watch(adminCountryOptionsProvider);
    return AlertDialog(
      title: Text(widget.item == null ? 'Add city' : 'Edit city'),
      content: SizedBox(
        width: 430,
        child: countries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => AdminErrorView(error: error),
          data: (List<CountryItem> values) {
            _countryId ??= values.isEmpty ? null : values.first.id;
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'City name'), validator: _required),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _countryId,
                    decoration: const InputDecoration(labelText: 'Country'),
                    items: values.map((CountryItem item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(growable: false),
                    onChanged: (String? value) => setState(() => _countryId = value),
                    validator: (String? value) => value == null ? 'Select a country.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _order, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number, validator: _integer),
                  if (widget.item != null)
                    SwitchListTile(value: _active, onChanged: (bool value) => setState(() => _active = value), title: const Text('Active')),
                  if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

const List<String> _supportedRecurrenceCodes = <String>[
  'none',
  'daily',
  'weekly',
  'monthly',
];

final class _ReferenceItemDialog extends ConsumerStatefulWidget {
  const _ReferenceItemDialog({required this.resource, required this.title, this.item});
  final String resource;
  final String title;
  final AdminReferenceItem? item;

  @override
  ConsumerState<_ReferenceItemDialog> createState() => _ReferenceItemDialogState();
}

final class _ReferenceItemDialogState extends ConsumerState<_ReferenceItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _order;
  bool _active = true;
  bool _saving = false;
  String? _error;

  bool get _isRecurrence => widget.resource == 'recurrence-types';

  String get _normalizedRecurrenceCode => _code.text.trim().toLowerCase();

  bool get _hasSupportedRecurrenceCode =>
      _supportedRecurrenceCodes.contains(_normalizedRecurrenceCode);

  bool get _canSelectRecurrenceCode =>
      _isRecurrence && (widget.item == null || !_hasSupportedRecurrenceCode);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name);
    final String? itemCode = widget.item?.code;
    _code = TextEditingController(
      text: widget.resource == 'recurrence-types'
          ? (itemCode?.trim().toLowerCase() ?? 'none')
          : itemCode,
    );
    _order = TextEditingController(text: '${widget.item?.sortOrder ?? 0}');
    _active = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final AdminRepository repository = ref.read(adminRepositoryProvider);
      if (widget.item == null) {
        await repository.createReferenceItem(resource: widget.resource, name: _name.text, code: _code.text, sortOrder: int.parse(_order.text));
      } else {
        await repository.updateReferenceItem(
          resource: widget.resource,
          item: AdminReferenceItem(
            id: widget.item!.id,
            code: _code.text.trim(),
            name: _name.text.trim(),
            isActive: _active,
            sortOrder: int.parse(_order.text),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Add ${widget.title}' : 'Edit ${widget.title}'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: _required),
                const SizedBox(height: 12),
                if (_isRecurrence)
                  DropdownButtonFormField<String>(
                    initialValue:
                        _hasSupportedRecurrenceCode ? _normalizedRecurrenceCode : null,
                    decoration: InputDecoration(
                      labelText: 'Behavior code',
                      helperText: widget.item == null
                          ? 'Select one of the recurrence rules supported by the application.'
                          : _hasSupportedRecurrenceCode
                              ? 'The behavior code is immutable; edit only the display name, order or active state.'
                              : 'This legacy code is unsupported. Select a supported replacement before saving.',
                    ),
                    items: _supportedRecurrenceCodes
                        .map(
                          (String code) => DropdownMenuItem<String>(
                            value: code,
                            child: Text(code),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: !_canSelectRecurrenceCode || _saving
                        ? null
                        : (String? value) {
                            if (value != null) {
                              setState(() => _code.text = value);
                            }
                          },
                    validator: (String? value) => value == null
                        ? 'Select a supported recurrence behavior.'
                        : null,
                  )
                else
                  TextFormField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Code'),
                    maxLength: 50,
                    validator: _required,
                  ),
                TextFormField(controller: _order, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number, validator: _integer),
                if (widget.item != null)
                  SwitchListTile(value: _active, onChanged: (bool value) => setState(() => _active = value), title: const Text('Active')),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      );
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? _integer(String? value) => int.tryParse(value ?? '') == null ? 'Enter a whole number.' : null;
