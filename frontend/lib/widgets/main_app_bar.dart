import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_provider.dart';
import 'package:agentic_ui/services/api_service.dart';
import '../services/theme_provider.dart';
import '../screens/login_screen.dart';
import '../screens/global_settings_screen.dart';
import '../screens/dashboard_screen.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isRightColumnExpanded;
  final VoidCallback? onToggleLayout;

  const MainAppBar({
    Key? key,
    this.isRightColumnExpanded = false,
    this.onToggleLayout,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showProfileDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final bool isAdmin = auth.role == 'administrator' || auth.role == 'admin';
    final agencyNameController = TextEditingController(text: auth.agencyName ?? '');
    final agencyAddressController = TextEditingController(text: auth.agencyAddress ?? '');
    final agencyContactController = TextEditingController(text: auth.agencyContactNumber ?? '');
    final agencyEmailController = TextEditingController(text: auth.agencyEmailAddress ?? '');
    bool isEditingAgency = false;
    bool isSavingAgency = false;
    final userNameController = TextEditingController(text: auth.userName ?? '');
    bool isEditingUserName = false;
    bool isSavingUserName = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Consumer<AuthProvider>(
              builder: (context, activeAuth, _) {
                return AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.badge_outlined, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('Agent & Company Profile'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Section 1: User Avatar Customization ---
                        Text(
                          'Agent Profile Picture',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.indigo.shade100,
                              backgroundImage: activeAuth.avatarUrl != null && activeAuth.avatarUrl!.isNotEmpty
                                  ? NetworkImage('http://127.0.0.1:8000${activeAuth.avatarUrl}')
                                  : null,
                              child: activeAuth.avatarUrl == null || activeAuth.avatarUrl!.isEmpty
                                  ? Text(
                                      (activeAuth.userName ?? 'U').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 32),
                                    )
                                  : null,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    try {
                                      final bytes = await image.readAsBytes();
                                      final result = await api.uploadUserAvatar(bytes, image.name);
                                      if (result.containsKey('avatar_url')) {
                                        activeAuth.updateAvatar(result['avatar_url']);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Profile picture updated successfully!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Upload failed: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isEditingUserName
                                ? SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: userNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter User Name',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : Text(
                                    activeAuth.userName ?? 'User Name',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                            const SizedBox(width: 8),
                            if (isEditingUserName) ...[
                              if (isSavingUserName)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else ...[
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green, size: 20),
                                  onPressed: () async {
                                    final newName = userNameController.text.trim();
                                    if (newName.isEmpty) return;
                                    setDialogState(() {
                                      isSavingUserName = true;
                                    });
                                    try {
                                      await api.updateUserName(newName);
                                      activeAuth.updateUserName(newName);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Profile name updated successfully!')),
                                        );
                                      }
                                      setDialogState(() {
                                        isEditingUserName = false;
                                      });
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to update: $e')),
                                        );
                                      }
                                    } finally {
                                      setDialogState(() {
                                        isSavingUserName = false;
                                      });
                                    }
                                  },
                                  tooltip: 'Save Name',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      userNameController.text = activeAuth.userName ?? '';
                                      isEditingUserName = false;
                                    });
                                  },
                                  tooltip: 'Cancel',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ] else ...[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.indigo),
                                onPressed: () {
                                  setDialogState(() {
                                    isEditingUserName = true;
                                  });
                                },
                                tooltip: 'Edit User Name',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Role: ${activeAuth.role?.toUpperCase() ?? 'AGENT'}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeAuth.userEmail ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Divider(height: 32),

                        // --- Section 2: Company Logo Customization (Admins Only) ---
                        Text(
                          'Company Customization',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade800 
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey.shade700 
                                    : Colors.grey.shade200
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- Company Logo Stack (Clickable to upload) ---
                                  GestureDetector(
                                    onTap: isAdmin ? () async {
                                      final picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                      if (image != null) {
                                        try {
                                          final bytes = await image.readAsBytes();
                                          final result = await api.uploadAgencyLogo(bytes, image.name);
                                          if (result.containsKey('logo_url')) {
                                            activeAuth.updateLogo(result['logo_url']);
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Company logo updated successfully!')),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Upload failed: $e')),
                                            );
                                          }
                                        }
                                      }
                                    } : null,
                                    child: MouseRegion(
                                      cursor: isAdmin ? SystemMouseCursors.click : SystemMouseCursors.basic,
                                      child: Tooltip(
                                        message: isAdmin ? 'Click to change logo' : 'Company Logo',
                                        child: Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.grey.shade900
                                                    : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.grey.shade700
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: activeAuth.logoUrl != null && activeAuth.logoUrl!.isNotEmpty
                                                    ? Image.network(
                                                        'http://127.0.0.1:8000${activeAuth.logoUrl}',
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 48, color: Colors.orange),
                                                    )
                                                    : const Icon(Icons.business, size: 48, color: Colors.orange),
                                              ),
                                            ),
                                            if (isAdmin)
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.indigo,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // --- Agency Information Details Column ---
                                  Expanded(
                                    child: isEditingAgency
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              TextField(
                                                controller: agencyNameController,
                                                decoration: InputDecoration(
                                                  labelText: 'Agency Name',
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: agencyAddressController,
                                                maxLines: 2,
                                                decoration: InputDecoration(
                                                  labelText: 'Agency Address',
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: agencyContactController,
                                                decoration: InputDecoration(
                                                  labelText: 'Contact Number',
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: agencyEmailController,
                                                decoration: InputDecoration(
                                                  labelText: 'Email Address',
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activeAuth.agencyName ?? 'Agentic Hub',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      activeAuth.agencyAddress ?? 'No address configured',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: activeAuth.agencyAddress != null ? null : Colors.grey.shade500,
                                                        fontStyle: activeAuth.agencyAddress != null ? null : FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      activeAuth.agencyContactNumber ?? 'No contact number',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: activeAuth.agencyContactNumber != null ? null : Colors.grey.shade500,
                                                        fontStyle: activeAuth.agencyContactNumber != null ? null : FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      activeAuth.agencyEmailAddress ?? 'No email configured',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: activeAuth.agencyEmailAddress != null ? null : Colors.grey.shade500,
                                                        fontStyle: activeAuth.agencyEmailAddress != null ? null : FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),
                                  
                                  // --- Edit / Save Action Buttons ---
                                  if (isAdmin) ...[
                                    if (!isEditingAgency)
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: Colors.indigo),
                                        onPressed: () {
                                          setDialogState(() {
                                            isEditingAgency = true;
                                          });
                                        },
                                        tooltip: 'Edit Agency Details',
                                      ),
                                  ],
                                ],
                              ),
                              if (isAdmin && isEditingAgency) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isSavingAgency)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    else ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Save', style: TextStyle(fontSize: 12)),
                                        onPressed: () async {
                                          final newName = agencyNameController.text.trim();
                                          final newAddress = agencyAddressController.text.trim();
                                          final newContact = agencyContactController.text.trim();
                                          final newEmail = agencyEmailController.text.trim();
                                          
                                          if (newName.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Agency name cannot be empty')),
                                            );
                                            return;
                                          }
                                          setDialogState(() {
                                            isSavingAgency = true;
                                          });
                                          try {
                                            await api.updateAgencyDetails(
                                              newName,
                                              address: newAddress.isNotEmpty ? newAddress : null,
                                              contactNumber: newContact.isNotEmpty ? newContact : null,
                                              emailAddress: newEmail.isNotEmpty ? newEmail : null,
                                            );
                                            activeAuth.updateAgencyDetails(
                                              newName,
                                              newAddress.isNotEmpty ? newAddress : null,
                                              newContact.isNotEmpty ? newContact : null,
                                              newEmail.isNotEmpty ? newEmail : null,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Agency details updated successfully!')),
                                              );
                                            }
                                            setDialogState(() {
                                              isEditingAgency = false;
                                            });
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Failed to update details: $e')),
                                              );
                                            }
                                          } finally {
                                            setDialogState(() {
                                              isSavingAgency = false;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          setDialogState(() {
                                            agencyNameController.text = activeAuth.agencyName ?? '';
                                            agencyAddressController.text = activeAuth.agencyAddress ?? '';
                                            agencyContactController.text = activeAuth.agencyContactNumber ?? '';
                                            agencyEmailController.text = activeAuth.agencyEmailAddress ?? '';
                                            isEditingAgency = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              if (!isAdmin) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Only administrators can customize company assets.',
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    return AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: auth.logoUrl != null && auth.logoUrl!.isNotEmpty
                      ? Image.network(
                          'http://127.0.0.1:8000${auth.logoUrl}',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 32, color: Colors.orange),
                        )
                      : const Icon(Icons.business, size: 32, color: Colors.orange),
                ),
                const SizedBox(width: 10),
                Text(
                  auth.agencyName ?? 'Agentic Property Hub', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
          if (onToggleLayout != null) IconButton(icon: Icon(isRightColumnExpanded ? Icons.splitscreen : Icons.fullscreen, color: Colors.white), onPressed: onToggleLayout, tooltip: isRightColumnExpanded ? 'Hide Summaries' : 'Show Summaries',),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const GlobalSettingsScreen()));
            },
            tooltip: 'Global Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }
            },
            tooltip: 'Logout',
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showProfileDialog(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'My Profile & Customization',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.userName ?? 'Agent',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty
                          ? NetworkImage('http://127.0.0.1:8000${auth.avatarUrl}')
                          : null,
                      child: auth.avatarUrl == null || auth.avatarUrl!.isEmpty
                          ? Text(
                              (auth.userName ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            )
                           : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      );
  }
}