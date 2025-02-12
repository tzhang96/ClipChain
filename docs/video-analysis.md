# Video Analysis Implementation Plan

## Overview
This document outlines the implementation plan for adding automated video analysis using Google's Gemini API via Firebase Cloud Functions. The analysis will provide video summaries, color analysis, style detection, and mood assessment to enhance video recommendations and search capabilities.

## Data Model Changes ✓

### VideoAnalysis Type ✓
```dart
class VideoAnalysis {
  final String summary;
  final List<String> colors;
  final String style;
  final String mood;
  final Timestamp analyzedAt;
  final String? error;        // Store any analysis errors
  final String status;        // pending, completed, failed
  
  // Add to FirestoreTypes
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_FAILED = 'failed';
}
```

### Firestore Schema Update ✓
```typescript
interface VideoDocument {
  // ... existing fields ...
  analysis?: {
    summary: string;
    colors: string[];
    style: string;
    mood: string;
    analyzedAt: Timestamp;
    error?: string;
    status: 'pending' | 'completed' | 'failed';
  }
}
```

## Implementation Checklist

### 1. Firebase Setup
- [x] Initialize Firebase Functions in project
- [x] Set up TypeScript environment for Functions
- [x] Add Gemini API key to Firebase environment variables
- [x] Configure Firebase Functions environment

### 2. Cloud Function Implementation
- [x] Create new function triggered by Firestore video document creation
- [x] Implement video analysis pipeline:
  - [x] Extract video URL and thumbnail URL from document
  - [x] Call Gemini API with both URLs
  - [x] Parse and validate Gemini response
  - [x] Update video document with analysis results
- [x] Add error handling and retries
- [x] Add logging for monitoring
- [x] Set up appropriate timeout configurations

### 3. Client-Side Updates

#### Data Model Updates
- [x] Add VideoAnalysis class to types/firestore_types.dart
- [x] Update VideoDocument to include analysis field
- [x] Add analysis status constants

#### VideoProvider Updates
- [x] Add analysis status tracking
- [x] Add methods to check analysis status
- [x] Add stream/method to listen for analysis updates
- [x] Update video cache when analysis completes

#### UI Updates
- [ ] Add analysis status indicator in video feed
- [ ] Create analysis results display component
- [ ] Add loading states for pending analysis
- [ ] Handle and display analysis errors

### 4. Testing Plan
- [ ] Unit tests for VideoAnalysis model
- [ ] Integration tests for Cloud Function
- [ ] Client-side UI tests
- [ ] Error handling tests
- [ ] Performance testing

### 5. Deployment Steps
1. [ ] Deploy Firestore schema updates
2. [ ] Deploy Cloud Function
3. [ ] Deploy client app updates
4. [ ] Monitor initial analysis runs
5. [ ] Verify error handling

## Cloud Function Pseudocode

```typescript
export const analyzeVideo = functions.firestore
  .document('videos/{videoId}')
  .onCreate(async (snap, context) => {
    const video = snap.data();
    
    try {
      // Set initial status
      await snap.ref.update({
        'analysis': {
          status: 'pending',
          analyzedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });

      // Get video data
      const videoUrl = video.videoUrl;
      const thumbnailUrl = video.thumbnailUrl;

      // Call Gemini API
      const analysis = await analyzeWithGemini(videoUrl, thumbnailUrl);

      // Update document
      await snap.ref.update({
        'analysis': {
          ...analysis,
          status: 'completed',
          analyzedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });

    } catch (error) {
      // Handle errors
      await snap.ref.update({
        'analysis': {
          status: 'failed',
          error: error.message,
          analyzedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });
      
      // Log error for monitoring
      console.error('Video analysis failed:', error);
    }
  });
```

## Gemini API Integration

### Required Prompts
We should structure our Gemini API calls to get consistent results:

```typescript
const ANALYSIS_PROMPT = `
Analyze this video and provide the following information:

1. Summary: A concise description of the video content (2-3 sentences)
2. Colors: List the main colors present in the video (up to 5)
3. Style: Describe the visual style (e.g., minimalist, vibrant, vintage, etc.)
4. Mood: Describe the emotional tone (e.g., energetic, calm, dramatic, etc.)

Format the response as JSON with the following structure:
{
  "summary": string,
  "colors": string[],
  "style": string,
  "mood": string
}
`;
```

## Monitoring and Maintenance

### Metrics to Track
- Analysis success rate
- Average analysis duration
- Error frequency by type
- API usage and costs
- Analysis queue length

### Maintenance Tasks
- Regular review of analysis quality
- Monitoring of API costs
- Updating prompts for better results
- Performance optimization
- Error pattern analysis

## Future Enhancements
- Batch analysis for existing videos
- More detailed video categorization
- Content warning detection
- Custom analysis for different video types
- Recommendation engine integration
- Search index integration

## Security Considerations
- Secure storage of API keys
- Rate limiting
- Access control for analysis results
- Data privacy compliance
- Error message sanitization

## Cost Considerations
- Gemini API usage costs
- Firebase Function execution costs
- Firestore read/write costs
- Monitoring costs
- Bandwidth costs 