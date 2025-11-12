import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/common/web_api_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/fade_box.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum SelectRemoteType { webDAV, webAPI }

class BackupAndRecovery extends ConsumerWidget {
  const BackupAndRecovery({super.key});

  Future<void> _showAddWebDAV(DAV? dav) async {
    await globalState.showCommonDialog<String>(
      child: WebDAVFormDialog(dav: dav?.copyWith()),
    );
  }

  Future<void> _showAddWebAPI(WebAPI? webAPI) async {
    await globalState.showCommonDialog<String>(
      child: WebAPIFormDialog(webAPI: webAPI?.copyWith()),
    );
  }

  Future<void> _backupOnWebDAV(DAVClient client) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final backupData = await globalState.appController.backupData();
        return await client.backup(Uint8List.fromList(backupData));
      },
      needLoading: true,
      title: appLocalizations.backup,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _recoveryOnWebDAV(
    BuildContext context,
    DAVClient client,
    RecoveryOption recoveryOption,
  ) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final data = await client.recovery();
        await globalState.appController.recoveryData(data, recoveryOption);
        return true;
      },
      needLoading: true,
      title: appLocalizations.recovery,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.recovery,
      message: TextSpan(text: appLocalizations.recoverySuccess),
    );
  }

  Future<void> _handleRecoveryOnWebDAV(
    BuildContext context,
    DAVClient client,
  ) async {
    final recoveryOption = await globalState.showCommonDialog<RecoveryOption>(
      child: const RecoveryOptionsDialog(),
    );
    if (recoveryOption == null || !context.mounted) return;
    _recoveryOnWebDAV(context, client, recoveryOption);
  }

  Future<void> _backupOnWebAPI(WebAPIClient client) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final backupData = await globalState.appController.backupData();
        return await client.upload(Uint8List.fromList(backupData));
      },
      needLoading: true,
      title: appLocalizations.backup,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _recoveryOnWebAPI(
    BuildContext context,
    WebAPIClient client,
    RecoveryOption recoveryOption,
  ) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final data = await client.download();
        await globalState.appController.recoveryData(data, recoveryOption);
        return true;
      },
      needLoading: true,
      title: appLocalizations.recovery,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.recovery,
      message: TextSpan(text: appLocalizations.recoverySuccess),
    );
  }

  Future<void> _handleRecoveryOnWebAPI(
    BuildContext context,
    WebAPIClient client,
  ) async {
    final recoveryOption = await globalState.showCommonDialog<RecoveryOption>(
      child: const RecoveryOptionsDialog(),
    );
    if (recoveryOption == null || !context.mounted) return;
    _recoveryOnWebAPI(context, client, recoveryOption);
  }

  Future<void> _backupOnLocal(BuildContext context) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final backupData = await globalState.appController.backupData();
        final value = await picker.saveFile(
          utils.getBackupFileName(),
          Uint8List.fromList(backupData),
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.backup,
      needLoading: true,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _recoveryOnLocal(RecoveryOption recoveryOption) async {
    final file = await picker.pickerFile();
    final data = file?.bytes;
    if (data == null) return;
    final res = await globalState.appController.safeRun<bool>(
      () async {
        await globalState.appController.recoveryData(
          List<int>.from(data),
          recoveryOption,
        );
        return true;
      },
      needLoading: true,
      title: appLocalizations.recovery,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.recovery,
      message: TextSpan(text: appLocalizations.recoverySuccess),
    );
  }

  Future<void> _handleRecoveryOnLocal(BuildContext context) async {
    final recoveryOption = await globalState.showCommonDialog<RecoveryOption>(
      child: const RecoveryOptionsDialog(),
    );
    if (recoveryOption == null || !context.mounted) return;
    _recoveryOnLocal(recoveryOption);
  }

  void _handleChange(String? value, WidgetRef ref) {
    if (value == null) {
      return;
    }
    ref
        .read(appDAVSettingProvider.notifier)
        .updateState((state) => state?.copyWith(fileName: value));
  }

  Future<void> _handleUpdateRecoveryStrategy(WidgetRef ref) async {
    final recoveryStrategy = ref.read(
      appSettingProvider.select((state) => state.recoveryStrategy),
    );
    final res = await globalState.showCommonDialog(
      child: OptionsDialog<RecoveryStrategy>(
        title: appLocalizations.recoveryStrategy,
        options: RecoveryStrategy.values,
        textBuilder: (mode) => Intl.message('recoveryStrategy_${mode.name}'),
        value: recoveryStrategy,
      ),
    );
    if (res == null) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .updateState((state) => state.copyWith(recoveryStrategy: res));
  }

  @override
  Widget build(BuildContext context, ref) {
    final dav = ref.watch(appDAVSettingProvider);
    final webAPI = ref.watch(appWebAPISettingProvider);
    final davClient = dav != null ? DAVClient(dav) : null;
    final webAPIClient = webAPI != null ? WebAPIClient(webAPI) : null;
    return ListView(
      children: [
        ListHeader(title: appLocalizations.remote),
        if (dav == null)
          ListItem(
            leading: const Icon(Icons.account_box),
            title: Text(appLocalizations.noInfo),
            subtitle: Text('${appLocalizations.pleaseBindWebDAV} (WebDAV)'),
            trailing: FilledButton.tonal(
              onPressed: () {
                _showAddWebDAV(null);
              },
              child: Text(appLocalizations.bind),
            ),
          )
        else ...[
          ListItem(
            leading: const Icon(Icons.account_box),
            title: TooltipText(
              text: Text(
                dav.user,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(appLocalizations.connectivity),
                  FutureBuilder<bool>(
                    future: davClient!.pingCompleter.future,
                    builder: (_, snapshot) {
                      return Center(
                        child: FadeThroughBox(
                          child:
                              snapshot.connectionState != ConnectionState.done
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: snapshot.data == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  width: 12,
                                  height: 12,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: () {
                _showAddWebDAV(dav);
              },
              child: Text(appLocalizations.edit),
            ),
          ),
          const SizedBox(height: 4),
          ListItem.input(
            title: Text(appLocalizations.file),
            subtitle: Text(dav.fileName ?? ''),
            delegate: InputDelegate(
              title: appLocalizations.file,
              value: dav.fileName ?? '',
              resetValue: defaultDavFileName,
              onChanged: (value) {
                _handleChange(value, ref);
              },
            ),
          ),
          ListItem(
            onTap: () {
              _backupOnWebDAV(davClient!);
            },
            title: Text(appLocalizations.backup),
            subtitle: Text('${appLocalizations.remoteBackupDesc} (WebDAV)'),
          ),
          ListItem(
            onTap: () {
              _handleRecoveryOnWebDAV(context, davClient!);
            },
            title: Text(appLocalizations.recovery),
            subtitle: Text('${appLocalizations.remoteRecoveryDesc} (WebDAV)'),
          ),
        ],
        const SizedBox(height: 16),
        ListHeader(title: '${appLocalizations.remote} (Web API)'),
        if (webAPI == null)
          ListItem(
            leading: const Icon(Icons.api),
            title: Text(appLocalizations.noInfo),
            subtitle: Text(appLocalizations.pleaseBindWebAPI),
            trailing: FilledButton.tonal(
              onPressed: () {
                _showAddWebAPI(null);
              },
              child: Text(appLocalizations.bind),
            ),
          )
        else ...[
          ListItem(
            leading: const Icon(Icons.api),
            title: TooltipText(
              text: Text(
                webAPI.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(appLocalizations.connectivity),
                  FutureBuilder<bool>(
                    future: webAPIClient!.pingCompleter.future,
                    builder: (_, snapshot) {
                      return Center(
                        child: FadeThroughBox(
                          child:
                              snapshot.connectionState != ConnectionState.done
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: snapshot.data == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  width: 12,
                                  height: 12,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: () {
                _showAddWebAPI(webAPI);
              },
              child: Text(appLocalizations.edit),
            ),
          ),
          ListItem(
            onTap: () {
              _backupOnWebAPI(webAPIClient!);
            },
            title: Text(appLocalizations.backup),
            subtitle: Text('${appLocalizations.remoteWebAPIBackupDesc} '),
          ),
          ListItem(
            onTap: () {
              _handleRecoveryOnWebAPI(context, webAPIClient!);
            },
            title: Text(appLocalizations.recovery),
            subtitle: Text('${appLocalizations.remoteWebAPIRecoveryDesc} '),
          ),
        ],
        ListHeader(title: appLocalizations.local),
        ListItem(
          onTap: () {
            _backupOnLocal(context);
          },
          title: Text(appLocalizations.backup),
          subtitle: Text(appLocalizations.localBackupDesc),
        ),
        ListItem(
          onTap: () {
            _handleRecoveryOnLocal(context);
          },
          title: Text(appLocalizations.recovery),
          subtitle: Text(appLocalizations.localRecoveryDesc),
        ),
        ListHeader(title: appLocalizations.options),
        Consumer(
          builder: (_, ref, _) {
            final recoveryStrategy = ref.watch(
              appSettingProvider.select((state) => state.recoveryStrategy),
            );
            return ListItem(
              onTap: () {
                _handleUpdateRecoveryStrategy(ref);
              },
              title: Text(appLocalizations.recoveryStrategy),
              trailing: FilledButton(
                onPressed: () {
                  _handleUpdateRecoveryStrategy(ref);
                },
                child: Text(
                  Intl.message('recoveryStrategy_${recoveryStrategy.name}'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class RecoveryOptionsDialog extends StatefulWidget {
  const RecoveryOptionsDialog({super.key});

  @override
  State<RecoveryOptionsDialog> createState() => _RecoveryOptionsDialogState();
}

class _RecoveryOptionsDialogState extends State<RecoveryOptionsDialog> {
  void _handleOnTab(RecoveryOption? value) {
    if (value == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.recovery,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              _handleOnTab(RecoveryOption.onlyProfiles);
            },
            title: Text(appLocalizations.recoveryProfiles),
          ),
          ListItem(
            onTap: () {
              _handleOnTab(RecoveryOption.all);
            },
            title: Text(appLocalizations.recoveryAll),
          ),
        ],
      ),
    );
  }
}

class WebDAVFormDialog extends ConsumerStatefulWidget {
  final DAV? dav;

  const WebDAVFormDialog({super.key, this.dav});

  @override
  ConsumerState<WebDAVFormDialog> createState() => _WebDAVFormDialogState();
}

class _WebDAVFormDialogState extends ConsumerState<WebDAVFormDialog> {
  late TextEditingController uriController;
  late TextEditingController userController;
  late TextEditingController passwordController;
  final _obscureController = ValueNotifier<bool>(true);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    uriController = TextEditingController(text: widget.dav?.uri);
    userController = TextEditingController(text: widget.dav?.user);
    passwordController = TextEditingController(text: widget.dav?.password);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(appDAVSettingProvider.notifier).value = DAV(
      uri: uriController.text,
      user: userController.text,
      password: passwordController.text,
    );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(appDAVSettingProvider.notifier).value = null;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _obscureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.webDAVConfiguration,
      actions: [
        if (widget.dav != null)
          TextButton(onPressed: _delete, child: Text(appLocalizations.delete)),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextFormField(
              controller: uriController,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.address,
                helperText: appLocalizations.addressHelp,
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty || !value.isUrl) {
                  return appLocalizations.addressTip;
                }
                return null;
              },
            ),
            TextFormField(
              controller: userController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_circle),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.account,
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(appLocalizations.account);
                }
                return null;
              },
            ),
            ValueListenableBuilder(
              valueListenable: _obscureController,
              builder: (_, obscure, _) {
                return TextFormField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.password),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _obscureController.value = !obscure;
                      },
                    ),
                    labelText: appLocalizations.password,
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.password,
                      );
                    }
                    return null;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WebAPIFormDialog extends ConsumerStatefulWidget {
  final WebAPI? webAPI;

  const WebAPIFormDialog({super.key, this.webAPI});

  @override
  ConsumerState<WebAPIFormDialog> createState() => _WebAPIFormDialogState();
}

class _WebAPIFormDialogState extends ConsumerState<WebAPIFormDialog> {
  late TextEditingController urlController;
  bool _autoDownload = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.webAPI?.url);
    _autoDownload = widget.webAPI?.autoDownload ?? false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(appWebAPISettingProvider.notifier).updateState((state) => WebAPI(
      url: urlController.text,
      autoDownload: _autoDownload,
    ));
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(appWebAPISettingProvider.notifier).updateState((state) => null);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.webDAVConfiguration.replaceAll('WebDAV', 'WebAPI'),
      actions: [
        if (widget.webAPI != null)
          TextButton(onPressed: _delete, child: Text(appLocalizations.delete)),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextFormField(
              controller: urlController,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.address,
                helperText: appLocalizations.addressHelp.replaceAll('WebDAV', 'WebAPI'),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty || !value.isUrl) {
                  return appLocalizations.addressTip.replaceAll('WebDAV', 'WebAPI');
                }
                return null;
              },
            ),
            SwitchListTile(
              value: _autoDownload,
              onChanged: (value) {
                setState(() {
                  _autoDownload = value;
                });
              },
              title: Text(appLocalizations.autoDownloadConfig),
              subtitle: Text(appLocalizations.autoDownloadConfigDesc),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectRemoteTypeDialog extends ConsumerWidget {
  const SelectRemoteTypeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonDialog(
      title: appLocalizations.remote,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              Navigator.of(context).pop(SelectRemoteType.webDAV);
            },
            title: Text('WebDAV'),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(SelectRemoteType.webAPI);
            },
            title: Text('Web API'),
          ),
        ],
      ),
    );
  }
}
