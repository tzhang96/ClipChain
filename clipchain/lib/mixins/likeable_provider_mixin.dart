import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../types/firestore_types.dart';

/// Interface for documents that can be liked
abstract class LikeableDocument {
  String get id;
  String get userId;
  int get likes;
}

/// Mixin that provides like functionality for a provider
mixin LikeableProviderMixin<T extends LikeableDocument> on ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache of liked item IDs for each user
  final Map<String, Set<String>> _userLikes = {}; // userId -> Set of itemIds
  
  // Set to track ongoing like operations
  final Set<String> _pendingLikes = {};
  
  // Loading states
  bool _isLoadingLikes = false;
  String? _likesError;

  bool get isLoadingLikes => _isLoadingLikes;
  String? get likesError => _likesError;

  // Abstract members to be implemented by the provider
  String get likesCollectionPath;
  String get documentsCollectionPath;
  T Function(Map<String, dynamic> data) get fromMap;
  void updateItemInCache(T item);
  String get likeableIdField;

  /// Check if an item is liked by a user
  bool isItemLiked(String userId, String itemId) {
    return _userLikes[userId]?.contains(itemId) ?? false;
  }

  /// Get all liked item IDs for a user
  Set<String> getLikedItemIds(String userId) {
    return _userLikes[userId] ?? {};
  }

  /// Load liked items for a user
  Future<void> loadUserLikes(String userId) async {
    try {
      Future.microtask(() {
        _isLoadingLikes = true;
        _likesError = null;
        notifyListeners();
      });

      final QuerySnapshot likesSnapshot = await _firestore
          .collection(likesCollectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      final likedItemIds = likesSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data[likeableIdField] as String?;
          })
          .where((id) => id != null)
          .map((id) => id!)
          .toSet();

      // Fetch the actual items
      final itemDocs = await Future.wait(
        likedItemIds.map((itemId) => 
          _firestore.collection(documentsCollectionPath).doc(itemId).get()
        )
      );

      final likedItems = itemDocs
          .where((doc) => doc.exists)
          .map((doc) {
            final data = doc.data()!;
            data['id'] = doc.id;
            return fromMap(data);
          })
          .toList();

      Future.microtask(() {
        _userLikes[userId] = likedItemIds;
        // Update items in cache
        for (final item in likedItems) {
          updateItemInCache(item);
        }
        _isLoadingLikes = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _likesError = 'Failed to load likes: $e';
        _isLoadingLikes = false;
        notifyListeners();
      });
    }
  }

  /// Toggle like status for an item with optimistic updates
  Future<void> toggleLike(String userId, String itemId) async {
    // Check if there's already a pending operation for this item
    final operationKey = '$userId:$itemId';
    if (_pendingLikes.contains(operationKey)) {
      return;
    }
    _pendingLikes.add(operationKey);

    try {
      final isLiked = isItemLiked(userId, itemId);
      
      // Get the current item from Firestore
      final itemDoc = await _firestore
          .collection(documentsCollectionPath)
          .doc(itemId)
          .get();
      
      if (!itemDoc.exists) {
        throw Exception('Item not found');
      }

      final currentData = itemDoc.data()!;
      currentData['id'] = itemDoc.id;
      final currentItem = fromMap(currentData);
      
      // Optimistically update local state
      Future.microtask(() {
        if (isLiked) {
          _userLikes[userId]?.remove(itemId);
          updateItemInCache(
            fromMap({
              ...currentData,
              'likes': currentItem.likes - 1,
            }),
          );
        } else {
          _userLikes.putIfAbsent(userId, () => {}).add(itemId);
          updateItemInCache(
            fromMap({
              ...currentData,
              'likes': currentItem.likes + 1,
            }),
          );
        }
        notifyListeners();
      });

      // Perform backend update
      if (isLiked) {
        // Unlike
        final likeDocs = await _firestore
            .collection(likesCollectionPath)
            .where('userId', isEqualTo: userId)
            .where(likeableIdField, isEqualTo: itemId)
            .get();
            
        await Future.wait([
          Future.wait(likeDocs.docs.map((doc) => doc.reference.delete())),
          _firestore
              .collection(documentsCollectionPath)
              .doc(itemId)
              .update({'likes': FieldValue.increment(-1)}),
        ]);
      } else {
        // Like
        await Future.wait([
          _firestore
              .collection(likesCollectionPath)
              .add({
                'userId': userId,
                likeableIdField: itemId,
                'createdAt': Timestamp.now(),
              }),
          _firestore
              .collection(documentsCollectionPath)
              .doc(itemId)
              .update({'likes': FieldValue.increment(1)}),
        ]);
      }

    } catch (e) {
      print('Error toggling like: $e');
      
      // Revert optimistic update on error
      final isLiked = isItemLiked(userId, itemId);
      
      // Get the current item state from Firestore
      final itemDoc = await _firestore
          .collection(documentsCollectionPath)
          .doc(itemId)
          .get();
          
      if (itemDoc.exists) {
        final data = itemDoc.data()!;
        data['id'] = itemDoc.id;
        
        Future.microtask(() {
          if (isLiked) {
            _userLikes[userId]?.add(itemId);
          } else {
            _userLikes[userId]?.remove(itemId);
          }
          updateItemInCache(fromMap(data));
          _likesError = 'Failed to update like status';
          notifyListeners();
        });
      }
    } finally {
      _pendingLikes.remove(operationKey);
    }
  }

  void clearLikes() {
    _userLikes.clear();
    _pendingLikes.clear();
    _isLoadingLikes = false;
    _likesError = null;
    notifyListeners();
  }
} 