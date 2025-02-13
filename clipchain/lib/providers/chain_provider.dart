import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../types/firestore_types.dart';
import '../mixins/likeable_provider_mixin.dart';

class ChainProvider with ChangeNotifier, LikeableProviderMixin<ChainDocument> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache of chains
  List<ChainDocument> _chains = [];
  Map<String, List<ChainDocument>> _userChains = {}; // Cache of user-specific chains
  
  // Loading states
  bool _isLoadingChains = false;
  bool _isLoadingUserChains = false;
  String? _chainsError;
  String? _userChainsError;

  // Getters
  List<ChainDocument> get chains => _chains;
  bool get isLoadingChains => _isLoadingChains;
  bool get isLoadingUserChains => _isLoadingUserChains;
  String? get chainsError => _chainsError;
  String? get userChainsError => _userChainsError;

  // Implement LikeableProviderMixin requirements
  @override
  String get likesCollectionPath => FirestorePaths.chainLikes;

  @override
  String get documentsCollectionPath => FirestorePaths.chains;

  @override
  ChainDocument Function(Map<String, dynamic> data) get fromMap => ChainDocument.fromMap;

  @override
  String get likeableIdField => 'chainId';

  @override
  void updateItemInCache(ChainDocument chain) {
    print('ChainProvider: Updating chain ${chain.id} in cache');
    final index = _chains.indexWhere((c) => c.id == chain.id);
    if (index != -1) {
      print('ChainProvider: Found chain at index $index');
      _chains[index] = chain;
      
      // Also update in user chains if present
      final userChains = _userChains[chain.userId];
      if (userChains != null) {
        final userIndex = userChains.indexWhere((c) => c.id == chain.id);
        if (userIndex != -1) {
          print('ChainProvider: Updating chain in user cache');
          userChains[userIndex] = chain;
        }
      }
    } else {
      print('ChainProvider: Chain not found in cache, adding it');
      _chains = [chain, ..._chains];
      
      // Also add to user chains if we have that user's chains
      final userChains = _userChains[chain.userId];
      if (userChains != null) {
        print('ChainProvider: Adding chain to user cache');
        _userChains[chain.userId] = [chain, ...userChains];
      }
    }
    notifyListeners();
  }

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

  // Add a chain to the main cache if it's not already there
  void addToMainCache(ChainDocument chain) {
    print('ChainProvider: Adding chain ${chain.id} to main cache');
    if (!_chains.any((c) => c.id == chain.id)) {
      _chains = [chain, ..._chains];
      print('ChainProvider: Chain added to main cache');
      // Schedule the notification for the next frame
      Future.microtask(() {
        notifyListeners();
      });
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

  /// Clear all cached data
  @override
  void clear() {
    _chains.clear();
    _userChains.clear();
    _isLoadingChains = false;
    _isLoadingUserChains = false;
    _chainsError = null;
    _userChainsError = null;
    clearLikes();  // Clear likes from the mixin
    notifyListeners();
  }

  /// Remove a video from all chains that contain it
  Future<void> removeVideoFromAllChains(String videoId) async {
    try {
      print('ChainProvider: Removing video $videoId from all chains');

      // Find all chains containing this video
      final QuerySnapshot chainSnapshot = await _firestore
          .collection(FirestorePaths.chains)
          .where('videoIds', arrayContains: videoId)
          .get();

      if (chainSnapshot.docs.isEmpty) {
        print('ChainProvider: No chains found containing video $videoId');
        return;
      }

      print('ChainProvider: Found ${chainSnapshot.docs.length} chains containing the video');

      // Start a batch write
      final batch = _firestore.batch();

      for (var doc in chainSnapshot.docs) {
        final chain = ChainDocument.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
        
        // Remove the video ID from the chain
        final updatedVideoIds = chain.videoIds.where((id) => id != videoId).toList();
        
        // Update the chain document
        batch.update(doc.reference, {
          'videoIds': updatedVideoIds,
          'updatedAt': Timestamp.now(),
        });

        // Update local cache
        final updatedChain = ChainDocument(
          id: chain.id,
          userId: chain.userId,
          title: chain.title,
          description: chain.description,
          likes: chain.likes,
          videoIds: updatedVideoIds,
          createdAt: chain.createdAt,
          updatedAt: Timestamp.now(),
        );

        // Update in main cache
        final index = _chains.indexWhere((c) => c.id == chain.id);
        if (index != -1) {
          _chains[index] = updatedChain;
        }

        // Update in user cache
        final userChains = _userChains[chain.userId];
        if (userChains != null) {
          final userIndex = userChains.indexWhere((c) => c.id == chain.id);
          if (userIndex != -1) {
            userChains[userIndex] = updatedChain;
          }
        }
      }

      // Commit all updates
      await batch.commit();

      print('ChainProvider: Successfully removed video from all chains');
      notifyListeners();
    } catch (e) {
      print('ChainProvider: Error removing video from chains: $e');
      rethrow;
    }
  }

  /// Get recommendations for a chain
  Future<List<VideoDocument>> getRecommendations(ChainDocument chain) async {
    try {
      print('ChainProvider: Getting recommendations for chain ${chain.id}');
      print('ChainProvider: Chain details - title: ${chain.title}, videoCount: ${chain.videoIds.length}');
      
      // Add chain to cache if not already there
      addToMainCache(chain);
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getChainRecommendations');
      
      final params = {
        'chainId': chain.id,
        'chainName': chain.title,
        'chainDescription': chain.description,
        'videoIds': chain.videoIds,
      };
      print('ChainProvider: Calling Cloud Function with params: $params');
      
      final result = await callable.call(params);
      
      print('ChainProvider: Received raw response: ${result.data}');
      
      if (result.data == null) {
        print('ChainProvider: Received null response from Cloud Function');
        return [];
      }

      if (result.data['recommendations'] == null) {
        print('ChainProvider: No recommendations in response');
        return [];
      }
      
      final recommendations = (result.data['recommendations'] as List).map((item) {
        print('ChainProvider: Processing recommendation item: $item');
        
        final videoData = item as Map<String, dynamic>;
        print('ChainProvider: Video data: $videoData');
        
        // Convert Timestamp data
        final createdAtData = videoData['createdAt'] as Map<String, dynamic>;
        final createdAt = Timestamp(
          createdAtData['_seconds'] as int,
          createdAtData['_nanoseconds'] as int,
        );

        // Create VideoAnalysis object if analysis exists
        VideoAnalysis? analysis;
        if (videoData['analysis'] != null) {
          final analysisData = videoData['analysis'] as Map<String, dynamic>;
          final analyzedAtData = analysisData['analyzedAt'] as Map<String, dynamic>;
          final analyzedAt = Timestamp(
            analyzedAtData['_seconds'] as int,
            analyzedAtData['_nanoseconds'] as int,
          );

          analysis = VideoAnalysis(
            summary: analysisData['summary'] as String,
            themes: List<String>.from(analysisData['themes'] as List),
            visuals: Map<String, List<String>>.from(
              (analysisData['visuals'] as Map<String, dynamic>).map(
                (key, value) => MapEntry(key, List<String>.from(value as List))
              )
            ),
            style: analysisData['style'] as String,
            mood: analysisData['mood'] as String,
            analyzedAt: analyzedAt,
            error: analysisData['error'] as String?,
            status: analysisData['status'] as String,
            version: analysisData['version'] as int,
            rawResponse: analysisData['rawResponse'] as String?,
          );
        }

        return VideoDocument(
          id: videoData['id'] as String,
          userId: videoData['userId'] as String,
          videoUrl: videoData['videoUrl'] as String,
          thumbnailUrl: videoData['thumbnailUrl'] as String?,
          description: videoData['description'] as String,
          likes: videoData['likes'] as int,
          createdAt: createdAt,
          analysis: analysis,
        );
      }).toList();

      print('ChainProvider: Successfully processed ${recommendations.length} recommendations');
      for (final video in recommendations) {
        print('ChainProvider: Recommendation - id: ${video.id}, title: ${video.description}');
      }

      return recommendations;
    } catch (e, stackTrace) {
      print('ChainProvider: Error getting recommendations: $e');
      print('ChainProvider: Stack trace:\n$stackTrace');
      return [];
    }
  }

  /// Add a video to a chain
  Future<void> addVideoToChain(String chainId, String videoId) async {
    try {
      final chainRef = _firestore.collection('chains').doc(chainId);
      await chainRef.update({
        'videoIds': FieldValue.arrayUnion([videoId]),
        'updatedAt': Timestamp.now(),
      });
      
      // Update local state
      final index = _chains.indexWhere((chain) => chain.id == chainId);
      if (index != -1) {
        final chain = _chains[index];
        final updatedChain = ChainDocument(
          id: chain.id,
          userId: chain.userId,
          title: chain.title,
          description: chain.description,
          likes: chain.likes,
          videoIds: [...chain.videoIds, videoId],
          createdAt: chain.createdAt,
          updatedAt: Timestamp.now(),
        );
        _chains[index] = updatedChain;
        notifyListeners();
      }
    } catch (e) {
      print('Error adding video to chain: $e');
      rethrow;
    }
  }
} 