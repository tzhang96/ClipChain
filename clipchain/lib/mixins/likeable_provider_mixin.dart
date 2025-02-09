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
  String get likeableIdField;  // New abstract getter for the ID field name

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

  /// Toggle like status for an item
  Future<void> toggleLike(String userId, String itemId) async {
    try {
      Future.microtask(() {
        _isLoadingLikes = true;
        _likesError = null;
        notifyListeners();
      });

      final isLiked = isItemLiked(userId, itemId);
      
      if (isLiked) {
        // Unlike
        await _firestore
            .collection(likesCollectionPath)
            .where('userId', isEqualTo: userId)
            .where(likeableIdField, isEqualTo: itemId)
            .get()
            .then((snapshot) {
          return Future.wait(
            snapshot.docs.map((doc) => doc.reference.delete()),
          );
        });

        // Update likes count
        await _firestore
            .collection(documentsCollectionPath)
            .doc(itemId)
            .update({'likes': FieldValue.increment(-1)});

      } else {
        // Like
        await _firestore
            .collection(likesCollectionPath)
            .add({
              'userId': userId,
              likeableIdField: itemId,
              'createdAt': Timestamp.now(),
            });

        // Update likes count
        await _firestore
            .collection(documentsCollectionPath)
            .doc(itemId)
            .update({'likes': FieldValue.increment(1)});
      }

      // Fetch updated item
      final updatedDoc = await _firestore
          .collection(documentsCollectionPath)
          .doc(itemId)
          .get();

      if (updatedDoc.exists) {
        final data = updatedDoc.data()!;
        data['id'] = updatedDoc.id;
        final updatedItem = fromMap(data);
        updateItemInCache(updatedItem);
      }

      // Update local cache
      Future.microtask(() {
        if (isLiked) {
          _userLikes[userId]?.remove(itemId);
        } else {
          _userLikes.putIfAbsent(userId, () => {}).add(itemId);
        }
        _isLoadingLikes = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _likesError = 'Failed to toggle like: $e';
        _isLoadingLikes = false;
        notifyListeners();
      });
    }
  }

  void clearLikes() {
    _userLikes.clear();
    _isLoadingLikes = false;
    _likesError = null;
    notifyListeners();
  }
} 