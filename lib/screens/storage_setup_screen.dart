import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../providers/api_config_provider.dart';

class StorageSetupScreen extends ConsumerStatefulWidget {
  const StorageSetupScreen({super.key});

  @override
  ConsumerState<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends ConsumerState<StorageSetupScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check: if already granted, just setup and go
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndProceedIfGranted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User might be coming back from settings
      _checkAndProceedIfGranted();
    }
  }

  Future<void> _checkAndProceedIfGranted() async {
    if (_isDesktop) return;

    final hasPermission = await _hasRequiredPermissions();
    if (hasPermission) {
      await _completeSetupWithDefaultFolder();
    }
  }

  Future<bool> _hasRequiredPermissions() async {
    if (Platform.isAndroid) {
      // On Android 11+, ManageExternalStorage is the strongest. 
      // On older, standard Storage is enough.
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      if (await Permission.photos.isGranted) return true;
      return false;
    } else if (Platform.isIOS) {
      return await Permission.photos.isGranted || await Permission.storage.isGranted;
    }
    return true; 
  }

  Future<void> _completeSetupWithDefaultFolder() async {
    setState(() => _isLoading = true);
    try {
      final storageService = ref.read(secureStorageServiceProvider);
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/Labi');
      } else {
        directory = await getApplicationDocumentsDirectory();
        directory = Directory(p.join(directory.path, 'Labi'));
      }

      if (!directory.existsSync()) {
        try {
          directory.createSync(recursive: true);
        } catch (e) {
          debugPrint('Failed to create Labi dir: $e');
        }
      }
      
      await storageService.saveGalleryPath(directory.path);
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Failed to complete setup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSetup() async {
    if (_isDesktop) {
      final chosenPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select destination folder for organized images',
      );

      if (chosenPath != null) {
        final storageService = ref.read(secureStorageServiceProvider);
        await storageService.saveGalleryPath(chosenPath);
        if (mounted) context.go('/');
      }
      return;
    }

    // Mobile Flow: Request permissions
    setState(() => _isLoading = true);
    try {
      final granted = await _requestMobilePermissions();
      if (granted) {
        await _completeSetupWithDefaultFolder();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestMobilePermissions() async {
    // 1. Check if permanently denied - if so, don't even try request(), just show dialog
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      final storageStatus = await Permission.storage.status;
      
      if (manageStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        if (mounted) _showPermissionDeniedDialog();
        return false;
      }
    }

    // 2. Try standard request
    PermissionStatus status = await Permission.storage.request();

    // 3. Try manage external storage on Android 11+
    if (!status.isGranted && Platform.isAndroid) {
      status = await Permission.manageExternalStorage.request();
    }
    
    // 4. Try media images as fallback
    if (!status.isGranted && Platform.isAndroid) {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        if (status.isPermanentlyDenied) {
          _showPermissionDeniedDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied. Please try again.')),
          );
        }
      }
      return false;
    }
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'lab-i cannot function without storage access to save and organize your classified images. '
          'Since this was denied, please enable it manually in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_special, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'lab-i needs a folder to store your sorted images. '
              'This folder will be used to save and organise all classified images '
              'and power your Gallery.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _handleSetup,
                    icon: Icon(_isDesktop ? Icons.folder_open : Icons.save_alt),
                    label: Text(
                      _isDesktop ? 'Choose Folder' : 'Grant Storage Access',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
