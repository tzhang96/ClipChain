import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI, GenerativeModel } from '@google/generative-ai';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

// Analysis prompt template
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

interface AnalysisResult {
  summary: string;
  colors: string[];
  style: string;
  mood: string;
}

interface VideoData {
  userId: string;
  videoUrl: string;
  thumbnailUrl: string;
  // ... other video fields
}

async function analyzeWithGemini(videoUrl: string, thumbnailUrl: string): Promise<AnalysisResult> {
  try {
    // Get Gemini model
    const model: GenerativeModel = genAI.getGenerativeModel({ model: 'gemini-pro-vision' });

    // Analyze the thumbnail first (as it's faster and more reliable)
    const result = await model.generateContent([
      ANALYSIS_PROMPT,
      {
        inlineData: {
          mimeType: 'image/jpeg',
          data: await fetchImageAsBase64(thumbnailUrl)
        }
      }
    ]);

    const response = await result.response;
    const text = response.text();
    
    // Parse the JSON response
    const analysis = JSON.parse(text) as AnalysisResult;
    
    // Validate the response structure
    if (!analysis.summary || !analysis.colors || !analysis.style || !analysis.mood) {
      throw new Error('Invalid analysis response structure');
    }

    return analysis;
  } catch (error) {
    console.error('Error analyzing with Gemini:', error);
    throw error;
  }
}

// Helper function to fetch image as base64
async function fetchImageAsBase64(url: string): Promise<string> {
  const response = await fetch(url);
  const buffer = await response.arrayBuffer();
  return Buffer.from(buffer).toString('base64');
}

// Cloud Function to analyze videos
export const analyzeVideo = functions.firestore.onDocumentCreated('videos/{videoId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data associated with the event');
    return;
  }

  const video = snapshot.data() as VideoData;
  const videoId = event.params.videoId;
  
  console.log(`Starting analysis for video ${videoId}`);
  
  try {
    // Set initial status
    await snapshot.ref.update({
      'analysis': {
        status: 'pending',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });

    // Get video data
    const videoUrl = video.videoUrl;
    const thumbnailUrl = video.thumbnailUrl;

    if (!thumbnailUrl) {
      throw new Error('No thumbnail URL available');
    }

    // Call Gemini API
    const analysis = await analyzeWithGemini(videoUrl, thumbnailUrl);

    // Update document with analysis results
    await snapshot.ref.update({
      'analysis': {
        ...analysis,
        status: 'completed',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });

    console.log(`Successfully analyzed video ${videoId}`);

  } catch (error) {
    console.error(`Error analyzing video ${videoId}:`, error);

    // Update document with error status
    await snapshot.ref.update({
      'analysis': {
        status: 'failed',
        error: error instanceof Error ? error.message : 'Unknown error',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });
  }
});

// Function to manually trigger analysis for a specific video
export const reanalyzeVideo = functions.https.onCall(async (request: functions.https.CallableRequest) => {
  // Ensure user is authenticated
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to reanalyze videos');
  }

  const { videoId } = request.data as { videoId: string };
  if (!videoId) {
    throw new functions.https.HttpsError('invalid-argument', 'Video ID is required');
  }

  try {
    // Get the video document
    const videoDoc = await admin.firestore()
      .collection('videos')
      .doc(videoId)
      .get();

    if (!videoDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Video not found');
    }

    const video = videoDoc.data() as VideoData;

    // Check if user has permission (is video owner or admin)
    if (request.auth.uid !== video.userId) {
      throw new functions.https.HttpsError('permission-denied', 'Must be video owner to reanalyze');
    }

    // Reset analysis status to pending
    await videoDoc.ref.update({
      'analysis': {
        status: 'pending',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: null
      }
    });

    // Call Gemini API
    const analysis = await analyzeWithGemini(video.videoUrl, video.thumbnailUrl);

    // Update document with analysis results
    await videoDoc.ref.update({
      'analysis': {
        ...analysis,
        status: 'completed',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });

    return { success: true };
  } catch (error) {
    console.error('Error reanalyzing video:', error);
    throw new functions.https.HttpsError('internal', 'Failed to reanalyze video');
  }
});

// Function to batch analyze videos
export const batchAnalyzeVideos = functions.https.onRequest(async (req, res) => {
  try {
    const batchSize = 50;
    const query = admin.firestore()
      .collection('videos')
      .where('analysis', '==', null)
      .limit(batchSize);

    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.size} videos to analyze`);

    const tasks = snapshot.docs.map(async (doc) => {
      const video = doc.data() as VideoData;
      try {
        const analysis = await analyzeWithGemini(video.videoUrl, video.thumbnailUrl);
        await doc.ref.update({
          'analysis': {
            ...analysis,
            status: 'completed',
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            version: 1
          }
        });
        return { id: doc.id, success: true };
      } catch (error) {
        console.error(`Error analyzing video ${doc.id}:`, error);
        await doc.ref.update({
          'analysis': {
            status: 'failed',
            error: error instanceof Error ? error.message : 'Unknown error',
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            version: 1
          }
        });
        return { id: doc.id, success: false, error: error instanceof Error ? error.message : 'Unknown error' };
      }
    });

    const results = await Promise.all(tasks);
    res.json({
      processed: snapshot.size,
      results
    });

  } catch (error) {
    console.error('Error in batchAnalyzeVideos:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}); 