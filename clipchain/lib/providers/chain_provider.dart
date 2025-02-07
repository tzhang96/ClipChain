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
    print('ChainProvider: Getting chain by ID: $chainId');
    print('ChainProvider: Current chains in cache: ${_chains.map((c) => "${c.id}: ${c.likes}").join(", ")}');
    final chain = _chains.cast<ChainDocument?>().firstWhere(
      (c) => c?.id == chainId,
      orElse: () => null,
    );
    print('ChainProvider: Found chain: ${chain?.id}, likes: ${chain?.likes}');
    return chain;
  }

  // Check if a chain is liked by a user
  bool isChainLiked(String userId, String chainId) {
    return _userLikedChains[userId]?.contains(chainId) ?? false;
  }

  // Get all chain IDs liked by a user
  Set<String> getLikedChainIds(String userId) {
    return _userLikedChains[userId] ?? {};
  }

  // Add a chain to the main cache if it's not already there
  void addToMainCache(ChainDocument chain) {
    print('ChainProvider: Adding chain ${chain.id} to main cache');
    if (!_chains.any((c) => c.id == chain.id)) {
      _chains = [chain, ..._chains];
      print('ChainProvider: Chain added to main cache');
      notifyListeners();
    } else {
      print('ChainProvider: Chain already in main cache');
    }
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
      print('ChainProvider: Toggling like for chain $chainId by user $userId');
      // Defer initial state update
      Future.microtask(() {
        _isLoadingLikes = true;
        _likesError = null;
        notifyListeners();
      });

      final isLiked = isChainLiked(userId, chainId);
      print('ChainProvider: Current like status: $isLiked');
      
      if (isLiked) {
        // Unlike
        print('ChainProvider: Unliking chain');
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

        // Fetch updated chain data
        final updatedDoc = await _firestore
            .collection(FirestorePaths.chains)
            .doc(chainId)
            .get();

        if (!updatedDoc.exists) {
          throw Exception('Chain not found');
        }

        final data = updatedDoc.data()!;
        data['id'] = updatedDoc.id;
        final updatedChain = ChainDocument.fromMap(data);
        print('ChainProvider: Fetched updated chain data - likes: ${updatedChain.likes}');

        // Schedule state update
        Future.microtask(() {
          print('ChainProvider: Updating cache with new chain data');
          _userLikedChains[userId]?.remove(chainId);
          
          // Update in main chains list
          final index = _chains.indexWhere((c) => c.id == chainId);
          if (index != -1) {
            print('ChainProvider: Updating chain in main cache at index $index');
            print('ChainProvider: Old likes: ${_chains[index].likes}, New likes: ${updatedChain.likes}');
            _chains[index] = updatedChain;
          } else {
            print('ChainProvider: Chain not found in main cache');
          }

          // Update in user chains list
          final userChains = _userChains[updatedChain.userId];
          if (userChains != null) {
            final userIndex = userChains.indexWhere((c) => c.id == chainId);
            if (userIndex != -1) {
              print('ChainProvider: Updating chain in user cache at index $userIndex');
              userChains[userIndex] = updatedChain;
            } else {
              print('ChainProvider: Chain not found in user cache');
            }
          }

          _isLoadingLikes = false;
          print('ChainProvider: Notifying listeners of update');
          notifyListeners();
        });

      } else {
        // Like
        print('ChainProvider: Liking chain');
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

        // Fetch updated chain data
        final updatedDoc = await _firestore
            .collection(FirestorePaths.chains)
            .doc(chainId)
            .get();

        if (!updatedDoc.exists) {
          throw Exception('Chain not found');
        }

        final data = updatedDoc.data()!;
        data['id'] = updatedDoc.id;
        final updatedChain = ChainDocument.fromMap(data);
        print('ChainProvider: Fetched updated chain data - likes: ${updatedChain.likes}');

        // Schedule state update
        Future.microtask(() {
          print('ChainProvider: Updating cache with new chain data');
          _userLikedChains.putIfAbsent(userId, () => {}).add(chainId);
          
          // Update in main chains list
          final index = _chains.indexWhere((c) => c.id == chainId);
          if (index != -1) {
            print('ChainProvider: Updating chain in main cache at index $index');
            print('ChainProvider: Old likes: ${_chains[index].likes}, New likes: ${updatedChain.likes}');
            _chains[index] = updatedChain;
          } else {
            print('ChainProvider: Chain not found in main cache');
          }

          // Update in user chains list
          final userChains = _userChains[updatedChain.userId];
          if (userChains != null) {
            final userIndex = userChains.indexWhere((c) => c.id == chainId);
            if (userIndex != -1) {
              print('ChainProvider: Updating chain in user cache at index $userIndex');
              userChains[userIndex] = updatedChain;
            } else {
              print('ChainProvider: Chain not found in user cache');
            }
          }

          _isLoadingLikes = false;
          print('ChainProvider: Notifying listeners of update');
          notifyListeners();
        });
      }

    } catch (e) {
      print('ChainProvider: Error toggling like: $e');
      Future.microtask(() {
        _likesError = 'Failed to toggle chain like: $e';
        _isLoadingLikes = false;
        notifyListeners();
      });
    }
  }
} 