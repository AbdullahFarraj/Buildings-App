import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_message_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../core/enums/user_role.dart';
import '../../core/theme/app_colors.dart';

class ChatSheet extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final String currentUserId;
  final String currentUserName;
  final bool isDirectChat;
  final List<String> receiverIds;

  const ChatSheet({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.currentUserId,
    required this.currentUserName,
    this.isDirectChat = false,
    this.receiverIds = const [],
  });

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  String _headerSubtitle = '';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      // Mark notifications as read for this chat
      await NotificationService().markChatNotificationsAsRead(widget.currentUserId, widget.chatId);
      
      // Fetch tenant details if it's a direct chat
      if (widget.isDirectChat) {
        final userModel = await _firestoreService.getUser(widget.chatId);
        if (userModel != null && mounted) {
          setState(() {
            if (userModel.role == UserRole.tenant) {
              _headerSubtitle = '${userModel.buildingId ?? 'No Building'} - Apt ${userModel.apartmentId ?? 'N/A'}';
            } else {
              _headerSubtitle = userModel.role.name.toUpperCase();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _initChat: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? fileUrl, String? fileName}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && fileUrl == null) return;

    setState(() => _isSending = true);

    try {
      if (widget.isDirectChat) {
        await _firestoreService.addDirectChatMessage(
          chatId: widget.chatId,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          text: text,
          fileUrl: fileUrl,
          fileName: fileName,
          receiverIds: widget.receiverIds,
        );
      } else {
        await _firestoreService.addTaskMessage(
          taskId: widget.chatId,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          text: text,
          fileUrl: fileUrl,
          fileName: fileName,
          receiverIds: widget.receiverIds,
        );
      }

      _messageController.clear();
      _scrollController.animateTo(
        0, // Reversed list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _pickAndUploadFile() async {
    PlatformFile? result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      String fileName = result.name;
      
      setState(() => _isSending = true);
      try {
        String? downloadUrl;
        
        if (kIsWeb) {
          final bytes = await result.readAsBytes();
          downloadUrl = await _storageService.uploadChatFileBytes(bytes, widget.chatId, fileName);
        } else {
          if (result.path != null) {
            File file = File(result.path!);
            downloadUrl = await _storageService.uploadChatFile(file, widget.chatId, fileName);
          }
        }

        if (downloadUrl != null) {
          _sendMessage(fileUrl: downloadUrl, fileName: fileName);
        } else {
          throw Exception("Could not get file data");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppColors.textPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    widget.chatTitle.isNotEmpty ? widget.chatTitle[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chatTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_headerSubtitle.isNotEmpty)
                        Text(
                          _headerSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat Background Color
          Expanded(
            child: Container(
              color: const Color(0xFFF0F2F5), // WhatsApp-like chat background
              child: StreamBuilder<List<TaskMessageModel>>(
              stream: widget.isDirectChat 
                  ? _firestoreService.getDirectChatMessages(widget.chatId)
                  : _firestoreService.getTaskMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Start the conversation!',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe) ...[
                              Text(
                                message.senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (message.text.isNotEmpty)
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            if (message.fileUrl != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final url = Uri.parse(message.fileUrl!);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        color: isMe ? Colors.white : AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          message.fileName ?? 'Attachment',
                                          style: TextStyle(
                                            color: isMe ? Colors.white : AppColors.textPrimary,
                                            decoration: TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a').format(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            ),
          ),

          // Input field
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                  onPressed: _isSending ? null : _pickAndUploadFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: _isSending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: () => _sendMessage(),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
