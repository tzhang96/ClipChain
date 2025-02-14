import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chain_provider.dart';
import '../types/firestore_types.dart';
import '../screens/create_chain_screen.dart';

class AddToChainSheet extends StatefulWidget {
  final String videoId;
  final String userId;

  const AddToChainSheet({
    super.key,
    required this.videoId,
    required this.userId,
  });

  @override
  State<AddToChainSheet> createState() => _AddToChainSheetState();
}

class _AddToChainSheetState extends State<AddToChainSheet> {
  bool _isLoading = false;
  String? _error;

  Future<void> _addToChain(ChainDocument chain) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chainProvider = context.read<ChainProvider>();
      final updatedChain = ChainDocument(
        id: chain.id,
        userId: chain.userId,
        title: chain.title,
        description: chain.description,
        likes: chain.likes,
        videoIds: [...chain.videoIds, widget.videoId],
        createdAt: chain.createdAt,
        updatedAt: chain.updatedAt,
      );

      final success = await chainProvider.updateChain(updatedChain);
      
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true); // Return success
        } else {
          setState(() => _error = 'Failed to add video to chain');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Add to Chain',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Create New Chain Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Create New Chain'),
              onTap: () async {
                // Close the sheet
                Navigator.of(context).pop();
                
                // Navigate to create chain screen
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => CreateChainScreen(
                      initialVideoId: widget.videoId,
                    ),
                  ),
                );

                // If chain was created successfully, return success
                if (result != null) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ),

          const Divider(),

          // Error message if any
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Existing chains list
          Expanded(
            child: Consumer<ChainProvider>(
              builder: (context, chainProvider, child) {
                final userChains = chainProvider.getChainsByUserId(widget.userId);

                if (userChains.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No chains available'),
                        const SizedBox(height: 8),
                        Text(
                          'Create a chain in the Create tab first',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: userChains.length,
                  itemBuilder: (context, index) {
                    final chain = userChains[index];
                    final alreadyContains = chain.videoIds.contains(widget.videoId);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          chain.title[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(chain.title),
                      subtitle: Text('${chain.videoIds.length} videos'),
                      trailing: alreadyContains
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                      enabled: !alreadyContains && !_isLoading,
                      onTap: alreadyContains || _isLoading
                        ? null
                        : () => _addToChain(chain),
                    );
                  },
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
} 