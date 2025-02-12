import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { GoogleAIFileManager, FileState } from '@google/generative-ai/server';
import fetch = require('node-fetch');
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

// Initialize Firebase Admin only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Initialize Gemini with API key
const apiKey = process.env.GEMINI_API_KEY || '';
const genAI = new GoogleGenerativeAI(apiKey);
const fileManager = new GoogleAIFileManager(apiKey);

interface VideoData {
  userId: string;
  videoUrl: string;
  thumbnailUrl: string;
  description?: string;  // Make description optional
}

async function waitForFileActive(file: any) {
  console.log(`Waiting for file ${file.displayName} to be processed...`);
  let currentFile = await fileManager.getFile(file.name);
  while (currentFile.state === FileState.PROCESSING) {
    console.log('File still processing...');
    await new Promise((resolve) => setTimeout(resolve, 10000));
    currentFile = await fileManager.getFile(file.name);
  }
  
  if (currentFile.state !== FileState.ACTIVE) {
    throw new Error(`File ${file.name} failed to process: ${currentFile.state}`);
  }
  console.log(`File ${file.displayName} is ready for inference`);
  return currentFile;
}

async function analyzeWithGemini(videoUrl: string, thumbnailUrl: string, description: string = ''): Promise<any> {
  console.log('Starting video analysis with Gemini...');
  console.log(`API Key length: ${apiKey.length}`);
  console.log(`Video URL: ${videoUrl}`);
  console.log(`Thumbnail URL: ${thumbnailUrl}`);

  try {
    // Download video to temp file
    const videoResponse = await fetch(videoUrl);
    const videoBuffer = await videoResponse.buffer();
    const tempVideoPath = path.join(os.tmpdir(), 'temp_video.mp4');
    fs.writeFileSync(tempVideoPath, videoBuffer);
    console.log('Video downloaded successfully');

    // Upload to Gemini File API
    const uploadResult = await fileManager.uploadFile(tempVideoPath, {
      mimeType: 'video/mp4',
      displayName: 'video_analysis',
    });
    console.log('Video uploaded to Gemini File API');

    // Wait for file to be processed
    const processedFile = await waitForFileActive(uploadResult.file);
    console.log('Video processing completed');

    // Initialize model with specific configuration
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      generationConfig: {
        temperature: 1,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 8192,
      },
    });

    // Build the analysis prompt
    const prompt = `Please analyze this video and provide the following information:
    1. A detailed summary of the content
    2. Key themes and topics
    3. Notable visual elements and colors
    4. Overall mood, style, and tone
    Additional context: ${description}`;

    // Use generateContent with the video file and text prompt in the correct order
    const result = await model.generateContent([
      {
        fileData: {
          mimeType: processedFile.mimeType,
          fileUri: processedFile.uri,
        },
      },
      { text: prompt },
    ]);

    console.log('Analysis completed successfully');

    // Clean up temp file
    fs.unlinkSync(tempVideoPath);

    return {
      summary: result.response.text(),
      raw_response: result.response.text(),
    };
  } catch (error) {
    console.error('Error in analyzeWithGemini:', error);
    throw error;
  }
}

// Core analysis function shared between triggers
async function performVideoAnalysis(
  videoRef: admin.firestore.DocumentReference,
  video: VideoData
) {
  const videoId = videoRef.id;
  console.log(`[DEBUG] Starting analysis for video ${videoId}`);
  console.log(`[DEBUG] Video data:`, JSON.stringify({
    videoId,
    videoUrl: video.videoUrl,
    thumbnailUrl: video.thumbnailUrl,
    userId: video.userId
  }));
  
  try {
    console.log(`[DEBUG] Setting initial pending status`);
    await videoRef.update({
      'analysis': {
        status: 'pending',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });
    console.log(`[DEBUG] Successfully set pending status`);

    if (!video.thumbnailUrl) {
      throw new Error('No thumbnail URL available');
    }

    console.log(`[DEBUG] Starting Gemini API call`);
    console.log(`[DEBUG] Using model: gemini-2.0-flash`);
    
    // Call Gemini API
    const analysis = await analyzeWithGemini(video.videoUrl, video.thumbnailUrl, video.description || '');
    console.log(`[DEBUG] Gemini API response:`, JSON.stringify(analysis));

    console.log(`[DEBUG] Updating document with analysis results`);
    await videoRef.update({
      'analysis': {
        ...analysis,
        status: 'completed',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });

    console.log(`[DEBUG] Successfully analyzed video ${videoId}`);
    return { success: true, analysis };

  } catch (error) {
    console.error(`[ERROR] Error analyzing video ${videoId}:`, error);
    console.error(`[ERROR] Error stack:`, error instanceof Error ? error.stack : 'No stack trace');

    console.log(`[DEBUG] Updating document with error status`);
    await videoRef.update({
      'analysis': {
        status: 'failed',
        error: error instanceof Error ? error.message : 'Unknown error',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1
      }
    });
    console.log(`[DEBUG] Successfully updated error status`);
    throw error;
  }
}

// Cloud Function to analyze videos on creation
export const analyzeVideo = functions.firestore.onDocumentCreated('videos/{videoId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data associated with the event');
    return;
  }

  const video = snapshot.data() as VideoData;
  await performVideoAnalysis(snapshot.ref, video);
});

// Function to manually trigger analysis for a specific video
export const reanalyzeVideo = functions.https.onCall(async (request: functions.https.CallableRequest) => {
  console.log('[DEBUG] reanalyzeVideo called with request:', JSON.stringify({
    auth: request.auth,
    data: request.data
  }, null, 2));

  // Ensure user is authenticated
  if (!request.auth) {
    console.error('[ERROR] Authentication missing');
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to reanalyze videos');
  }

  if (!request.auth.uid) {
    console.error('[ERROR] UID missing from auth context');
    throw new functions.https.HttpsError('unauthenticated', 'Invalid authentication');
  }

  const { videoId } = request.data as { videoId: string };
  if (!videoId) {
    console.error('[ERROR] Video ID missing from request');
    throw new functions.https.HttpsError('invalid-argument', 'Video ID is required');
  }

  try {
    console.log(`[DEBUG] Getting video document ${videoId}`);
    // Get the video document
    const videoRef = admin.firestore().collection('videos').doc(videoId);
    const videoDoc = await videoRef.get();

    if (!videoDoc.exists) {
      console.error(`[ERROR] Video ${videoId} not found`);
      throw new functions.https.HttpsError('not-found', 'Video not found');
    }

    const video = videoDoc.data() as VideoData;
    console.log(`[DEBUG] Video data:`, JSON.stringify(video, null, 2));
    console.log(`[DEBUG] Auth UID: ${request.auth.uid}, Video User ID: ${video.userId}`);

    // Check if user has permission (is video owner or admin)
    if (request.auth.uid !== video.userId) {
      console.error(`[ERROR] Permission denied. Auth UID ${request.auth.uid} does not match video owner ${video.userId}`);
      throw new functions.https.HttpsError('permission-denied', 'Must be video owner to reanalyze');
    }

    console.log('[DEBUG] Authorization successful, proceeding with analysis');
    await performVideoAnalysis(videoRef, video);
    return { success: true };
  } catch (error) {
    console.error('[ERROR] Error in reanalyzeVideo:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
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
        await performVideoAnalysis(doc.ref, video);
        return { id: doc.id, success: true };
      } catch (error) {
        return { 
          id: doc.id, 
          success: false, 
          error: error instanceof Error ? error.message : 'Unknown error' 
        };
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