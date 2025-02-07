import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class ChainProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache of chains
  List<ChainDocument> _chains = [];
  Map<String, List<ChainDocument>> _userChains = {}; // Cache of user-specific chains
  Map<String, Set<String>> _userLikedChains = {}; // Cache of chain IDs liked by users
  
  // Loading states
  bool _isLoadingChains = false;
  bool _isLoadingUserChains = false;
  bool _isLoadingLikes = false;
  
  // Error states
  String? _chainsError;
  String? _userChainsError;
  String? _likesError;

  // Getters
  List<ChainDocument> get chains => _chains;
  bool get isLoadingChains => _isLoadingChains;
  bool get isLoadingUserChains => _isLoadingUserChains;
  bool get isLoadingLikes => _isLoadingLikes;
  String? get chainsError => _chainsError;
  String? get userChainsError => _userChainsError;
  String? get likesError => _likesError;

  // Get chains for a specific user
  List<ChainDocument> getChainsByUserId(String userId) {
    return _userChains[userId] ?? [];
  }

  // Get a single chain by ID
  ChainDocument? getChainById(String chainId) {
    return _chains.cast<ChainDocument?>().firstWhere(
      (c) => c?.id == chainId,
      orElse: () => null,
    );
  }

  // Check if a chain is liked by a user
  bool isChainLiked(String userId, String chainId) {
    return _userLikedChains[userId]?.contains(chainId) ?? false;
  }

  // Get all chain IDs liked by a user
  Set<String> getLikedChainIds(String userId) {
    return _userLikedChains[userId] ?? {};
  }

  /// Create a new chain
  Future<ChainDocument?> createChain({
    required String userId,
    required String title,
    String? description,
    List<String> initialVideoIds = const [],
  }) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingChains = true;
        _chainsError = null;
        notifyListeners();
      });

      final chain = ChainDocument(
        id: '', // Will be set by Firestore
        userId: userId,
        title: title,
        description: description,
        likes: 0,
        videoIds: initialVideoIds,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      final docRef = await _firestore
          .collection(FirestorePaths.chains)
          .add(chain.toMap());

      final newChain = ChainDocument(
        id: docRef.id,
        userId: chain.userId,
        title: chain.title,
        description: chain.description,
        likes: chain.likes,
        videoIds: chain.videoIds,
        createdAt: chain.createdAt,
        updatedAt: chain.updatedAt,
      );

      // Update local caches
      Future.microtask(() {
        _chains = [newChain, ..._chains];
        _userChains[userId] = [newChain, ...(_userChains[userId] ?? [])];
        _isLoadingChains = false;
        notifyListeners();
      });

      return newChain;
    } catch (e) {
      Future.microtask(() {
        _chainsError = 'Failed to create chain: $e';
        _isLoadingChains = false;
        notifyListeners();
      });
      return null;
    }
  }

  /// Update an existing chain
  Future<bool> updateChain(ChainDocument updatedChain) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingChains = true;
        _chainsError = null;
        notifyListeners();
      });

      await _firestore
          .collection(FirestorePaths.chains)
          .doc(updatedChain.id)
          .update({
            ...updatedChain.toMap(),
            'updatedAt': Timestamp.now(),
          });

      // Update local caches
      Future.microtask(() {
        final index = _chains.indexWhere((c) => c.id == updatedChain.id);
        if (index != -1) {
          _chains[index] = updatedChain;
        }

        final userChains = _userChains[updatedChain.userId];
        if (userChains != null) {
          final userIndex = userChains.indexWhere((c) => c.id == updatedChain.id);
          if (userIndex != -1) {
            userChains[userIndex] = updatedChain;
          }
        }

        _isLoadingChains = false;
        notifyListeners();
      });

      return true;
    } catch (e) {
      Future.microtask(() {
        _chainsError = 'Failed to update chain: $e';
        _isLoadingChains = false;
        notifyListeners();
      });
      return false;
    }
  }

  /// Delete a chain
  Future<bool> deleteChain(String chainId, String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingChains = true;
        _chainsError = null;
        notifyListeners();
      });

      await _firestore
          .collection(FirestorePaths.chains)
          .doc(chainId)
          .delete();

      // Update local caches
      Future.microtask(() {
        _chains.removeWhere((c) => c.id == chainId);
        _userChains[userId]?.removeWhere((c) => c.id == chainId);
        _isLoadingChains = false;
        notifyListeners();
      });

      return true;
    } catch (e) {
      Future.microtask(() {
        _chainsError = 'Failed to delete chain: $e';
        _isLoadingChains = false;
        notifyListeners();
      });
      return false;
    }
  }

  /// Fetch all public chains
  Future<void> fetchChains() async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingChains = true;
        _chainsError = null;
        notifyListeners();
      });

      final QuerySnapshot chainSnapshot = await _firestore
          .collection(FirestorePaths.chains)
          .orderBy('createdAt', descending: true)
          .get();

      final chains = chainSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ChainDocument.fromMap(data);
          })
          .toList();

      // Schedule state update after async complete
      Future.microtask(() {
        _chains = chains;
        _isLoadingChains = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _chainsError = 'Failed to fetch chains: $e';
        _isLoadingChains = false;
        notifyListeners();
      });
    }
  }

  /// Fetch chains for a specific user
  Future<void> fetchUserChains(String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingUserChains = true;
        _userChainsError = null;
        notifyListeners();
      });

      final QuerySnapshot chainSnapshot = await _firestore
          .collection(FirestorePaths.chains)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final userChains = chainSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ChainDocument.fromMap(data);
          })
          .toList();

      // Schedule state update after async complete
      Future.microtask(() {
        _userChains[userId] = userChains;
        _isLoadingUserChains = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _userChainsError = 'Failed to fetch user chains: $e';
        _isLoadingUserChains = false;
        notifyListeners();
      });
    }
  }

  /// Load liked chains for a user
  Future<void> loadUserLikedChains(String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingLikes = true;
        _likesError = null;
        notifyListeners();
      });

      final QuerySnapshot likesSnapshot = await _firestore
          .collection(FirestorePaths.chainLikes)
          .where('userId', isEqualTo: userId)
          .get();

      final likedChainIds = likesSnapshot.docs
          .map((doc) => doc.get('chainId') as String)
          .toSet();

      // Schedule state update after async complete
      Future.microtask(() {
        _userLikedChains[userId] = likedChainIds;
        _isLoadingLikes = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _likesError = 'Failed to load liked chains: $e';
        _isLoadingLikes = false;
        notifyListeners();
      });
    }
  }

  /// Toggle like status for a chain
  Future<void> toggleChainLike(String userId, String chainId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingLikes = true;
        _likesError = null;
        notifyListeners();
      });

      final isLiked = isChainLiked(userId, chainId);
      
      if (isLiked) {
        // Unlike
        await _firestore
            .collection(FirestorePaths.chainLikes)
            .where('userId', isEqualTo: userId)
            .where('chainId', isEqualTo: chainId)
            .get()
            .then((snapshot) {
          return Future.wait(
            snapshot.docs.map((doc) => doc.reference.delete()),
          );
        });

        // Update chain likes count
        await _firestore
            .collection(FirestorePaths.chains)
            .doc(chainId)
            .update({'likes': FieldValue.increment(-1)});

        // Schedule state update
        Future.microtask(() {
          _userLikedChains[userId]?.remove(chainId);
          final chain = getChainById(chainId);
          if (chain != null) {
            final updatedChain = ChainDocument(
              id: chain.id,
              userId: chain.userId,
              title: chain.title,
              description: chain.description,
              likes: chain.likes - 1,
              videoIds: chain.videoIds,
              createdAt: chain.createdAt,
              updatedAt: chain.updatedAt,
            );
            final index = _chains.indexWhere((c) => c.id == chainId);
            if (index != -1) {
              _chains[index] = updatedChain;
            }
            final userChains = _userChains[chain.userId];
            if (userChains != null) {
              final userIndex = userChains.indexWhere((c) => c.id == chainId);
              if (userIndex != -1) {
                userChains[userIndex] = updatedChain;
              }
            }
          }
          _isLoadingLikes = false;
          notifyListeners();
        });

      } else {
        // Like
        await _firestore
            .collection(FirestorePaths.chainLikes)
            .add({
              'userId': userId,
              'chainId': chainId,
              'createdAt': Timestamp.now(),
            });

        // Update chain likes count
        await _firestore
            .collection(FirestorePaths.chains)
            .doc(chainId)
            .update({'likes': FieldValue.increment(1)});

        // Schedule state update
        Future.microtask(() {
          _userLikedChains.putIfAbsent(userId, () => {}).add(chainId);
          final chain = getChainById(chainId);
          if (chain != null) {
            final updatedChain = ChainDocument(
              id: chain.id,
              userId: chain.userId,
              title: chain.title,
              description: chain.description,
              likes: chain.likes + 1,
              videoIds: chain.videoIds,
              createdAt: chain.createdAt,
              updatedAt: chain.updatedAt,
            );
            final index = _chains.indexWhere((c) => c.id == chainId);
            if (index != -1) {
              _chains[index] = updatedChain;
            }
            final userChains = _userChains[chain.userId];
            if (userChains != null) {
              final userIndex = userChains.indexWhere((c) => c.id == chainId);
              if (userIndex != -1) {
                userChains[userIndex] = updatedChain;
              }
            }
          }
          _isLoadingLikes = false;
          notifyListeners();
        });
      }

    } catch (e) {
      Future.microtask(() {
        _likesError = 'Failed to toggle chain like: $e';
        _isLoadingLikes = false;
        notifyListeners();
      });
    }
  }
} 