import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { GoogleAIFileManager, FileState } from '@google/generative-ai/server';
import * as nodeFetch from 'node-fetch';
const Replicate = require('replicate');
const fetch = nodeFetch.default;
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import OpenAI from 'openai';
import { Pinecone, RecordMetadata } from '@pinecone-database/pinecone';
import { CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Define secrets
const geminiApiKey = defineSecret('GEMINI_API_KEY');
const openaiApiKey = defineSecret('OPENAI_API_KEY');
const pineconeApiKey = defineSecret('PINECONE_API_KEY');
const pineconeIndex = defineSecret('PINECONE_INDEX');

interface PineconeMetadata extends RecordMetadata {
  videoId: string;
  type: 'content' | 'visual' | 'mood';
  userId: string;
  description: string;
  createdAt: string; // Store timestamp as ISO string
}

interface VideoAnalysisResponse {
  summary: string;
  themes: string[];
  visuals: {
    colors: string[];
    elements: string[];
  };
  style: string;
  mood: string;
  raw_response: string;
}

interface VideoEmbeddings {
  contentEmbedding: number[];
  visualEmbedding: number[];
  moodEmbedding: number[];
}

// Remove top-level initializations
interface VideoData {
  id: string;
  userId: string;
  videoUrl: string;
  thumbnailUrl?: string;
  description: string;
  likes: number;
  createdAt: admin.firestore.Timestamp;
  analysis?: {
    summary: string;
    themes: string[];
    visuals: {
      colors: string[];
      elements: string[];
    };
    style: string;
    mood: string;
    analyzedAt: admin.firestore.Timestamp;
    error?: string;
    status: 'pending' | 'completed' | 'failed';
    version: number;
    hasEmbeddings?: boolean;
    rawResponse?: string;
  };
}

async function waitForFileActive(fileManager: GoogleAIFileManager, file: any) {
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

async function analyzeWithGemini(apiKey: string, videoUrl: string, thumbnailUrl: string, description: string = ''): Promise<VideoAnalysisResponse> {
  console.log('Starting video analysis with Gemini...');
  
  // Initialize services inside the function
  const genAI = new GoogleGenerativeAI(apiKey);
  const fileManager = new GoogleAIFileManager(apiKey);

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
    const processedFile = await waitForFileActive(fileManager, uploadResult.file);
    console.log('Video processing completed');

    // Initialize model with specific configuration
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      generationConfig: {
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
        maxOutputTokens: 8192,
      },
    });

    // Build the analysis prompt
    const prompt = `Analyze this video and provide a structured response in the following JSON format:
{
  "summary": "A concise 2-3 sentence description of the video content",
  "themes": ["theme1", "theme2", "theme3"],
  "visuals": {
    "colors": ["color1", "color2", "color3"],
    "elements": ["element1", "element2", "element3"]
  },
  "style": "Brief description of the visual style (e.g., minimalist, vibrant, vintage)",
  "mood": "Brief description of the emotional tone (e.g., energetic, calm, dramatic)"
}

User-provided description of the video for additional context: ${description}

Important:
- Keep the summary brief and focused
- List only the most prominent themes, colors, and elements (max 5 each)
- Ensure the response is valid JSON
- Do not include any text outside the JSON object`;

    // Use generateContent with the video file and text prompt
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

    // Parse the response as JSON
    const rawResponse = result.response.text();
    console.log('Raw response:', rawResponse);

    try {
      // Extract JSON from the response (in case there's any extra text)
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('No JSON object found in response');
      }

      const jsonStr = jsonMatch[0];
      console.log('Extracted JSON:', jsonStr);

      const parsedResponse = JSON.parse(jsonStr);

      // Validate and normalize the response
      const normalizedResponse: VideoAnalysisResponse = {
        summary: String(parsedResponse.summary || ''),
        themes: Array.isArray(parsedResponse.themes) ? parsedResponse.themes.map(String) : [],
        visuals: {
          colors: Array.isArray(parsedResponse.visuals?.colors) ? parsedResponse.visuals.colors.map(String) : [],
          elements: Array.isArray(parsedResponse.visuals?.elements) ? parsedResponse.visuals.elements.map(String) : [],
        },
        style: String(parsedResponse.style || ''),
        mood: String(parsedResponse.mood || ''),
        raw_response: rawResponse,
      };

      console.log('Normalized response:', normalizedResponse);
      return normalizedResponse;

    } catch (parseError) {
      console.error('Error parsing Gemini response as JSON:', parseError);
      console.error('Raw response:', rawResponse);

      // Return a structured error response
      return {
        summary: 'Failed to parse analysis results',
        themes: [],
        visuals: {
          colors: [],
          elements: [],
        },
        style: 'unknown',
        mood: 'unknown',
        raw_response: rawResponse,
      };
    }
  } catch (error) {
    console.error('Error in analyzeWithGemini:', error);
    throw error;
  }
}

async function generateEmbeddings(apiKey: string, analysis: VideoAnalysisResponse): Promise<VideoEmbeddings> {
  // Initialize OpenAI inside the function
  const openai = new OpenAI({ apiKey });

  // Create a comprehensive content representation including all analysis elements
  const contentText = [
    analysis.summary,
    `Themes: ${analysis.themes.join(', ')}`,
    `Style: ${analysis.style}`,
    `Mood: ${analysis.mood}`,
    `Visual elements: ${analysis.visuals.elements.join(', ')}`,
    `Colors: ${analysis.visuals.colors.join(', ')}`
  ].join('\n');

  // Keep visual and mood embeddings focused on their specific aspects
  const visualText = `${analysis.style} ${analysis.visuals.colors.join(' ')} ${analysis.visuals.elements.join(' ')}`;
  const moodText = analysis.mood;

  // Generate embeddings in parallel
  const [contentEmbed, visualEmbed, moodEmbed] = await Promise.all([
    openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: contentText,
    }),
    openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: visualText,
    }),
    openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: moodText,
    }),
  ]);

  return {
    contentEmbedding: contentEmbed.data[0].embedding,
    visualEmbedding: visualEmbed.data[0].embedding,
    moodEmbedding: moodEmbed.data[0].embedding,
  };
}

async function storeEmbeddings(
  pineconeApiKeyValue: string,
  pineconeIndexValue: string,
  videoId: string, 
  embeddings: VideoEmbeddings, 
  metadata: {
    userId: string;
    description: string;
    createdAt: string;
  }
) {
  // Initialize Pinecone inside the function
  const pinecone = new Pinecone({
    apiKey: pineconeApiKeyValue,
  });
  
  const index = pinecone.index(pineconeIndexValue);
  
  // Store embeddings with metadata
  await index.upsert([
    {
      id: `${videoId}_content`,
      values: embeddings.contentEmbedding,
      metadata: {
        videoId,
        type: 'content',
        ...metadata,
      },
    },
    {
      id: `${videoId}_visual`,
      values: embeddings.visualEmbedding,
      metadata: {
        videoId,
        type: 'visual',
        ...metadata,
      },
    },
    {
      id: `${videoId}_mood`,
      values: embeddings.moodEmbedding,
      metadata: {
        videoId,
        type: 'mood',
        ...metadata,
      },
    },
  ]);
}

// Core analysis function shared between triggers
async function performVideoAnalysis(
  videoRef: admin.firestore.DocumentReference,
  video: VideoData,
  secrets: {
    geminiApiKey: string;
    openaiApiKey: string;
    pineconeApiKey: string;
    pineconeIndex: string;
  }
) {
  // Initialize Firebase Admin if not already initialized
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

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
    
    // Call Gemini API with the API key
    const analysis = await analyzeWithGemini(secrets.geminiApiKey, video.videoUrl, video.thumbnailUrl, video.description || '');
    console.log(`[DEBUG] Gemini API response:`, JSON.stringify(analysis));

    // Generate embeddings with the OpenAI key
    const embeddings = await generateEmbeddings(secrets.openaiApiKey, analysis);
    
    // Store embeddings with the Pinecone credentials
    await storeEmbeddings(
      secrets.pineconeApiKey,
      secrets.pineconeIndex,
      videoId,
      embeddings,
      {
        userId: video.userId,
        description: video.description || '',
        createdAt: new Date().toISOString(),
      }
    );

    // Update Firestore document with analysis results
    await videoRef.update({
      'analysis': {
        ...analysis,
        status: 'completed',
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        version: 1,
        hasEmbeddings: true,
      }
    });

    console.log(`[DEBUG] Successfully analyzed video and stored embeddings ${videoId}`);
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
export const analyzeVideo = functions.firestore
  .onDocumentCreated({
    document: 'videos/{videoId}',
    secrets: [geminiApiKey, openaiApiKey, pineconeApiKey, pineconeIndex]
  }, async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log('No data associated with the event');
      return;
    }

    const video = snapshot.data() as VideoData;
    await performVideoAnalysis(snapshot.ref, video, {
      geminiApiKey: geminiApiKey.value(),
      openaiApiKey: openaiApiKey.value(),
      pineconeApiKey: pineconeApiKey.value(),
      pineconeIndex: pineconeIndex.value(),
    });
  });

// Function to manually trigger analysis for a specific video
export const reanalyzeVideo = functions.https.onCall({
  secrets: [geminiApiKey, openaiApiKey, pineconeApiKey, pineconeIndex]
}, async (request: functions.https.CallableRequest) => {
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
    await performVideoAnalysis(videoRef, video, {
      geminiApiKey: geminiApiKey.value(),
      openaiApiKey: openaiApiKey.value(),
      pineconeApiKey: pineconeApiKey.value(),
      pineconeIndex: pineconeIndex.value(),
    });
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
export const batchAnalyzeVideos = functions.https.onRequest({
  secrets: [geminiApiKey, openaiApiKey, pineconeApiKey, pineconeIndex]
}, async (req, res) => {
  try {
    const batchSize = 50;
    
    // Get videos that need analysis
    const snapshot = await admin.firestore()
      .collection('videos')
      .where('analysis', 'in', [null, undefined]) // Missing analysis
      .orderBy('createdAt', 'desc')
      .limit(batchSize)
      .get();

    // Get videos with failed analysis
    const failedSnapshot = await admin.firestore()
      .collection('videos')
      .where('analysis.status', '==', 'failed')
      .orderBy('createdAt', 'desc')
      .limit(batchSize)
      .get();

    // Get videos with potentially malformed analysis
    const malformedSnapshot = await admin.firestore()
      .collection('videos')
      .where('analysis.status', '==', 'completed')
      .where('analysis.hasEmbeddings', '==', false)
      .orderBy('createdAt', 'desc')
      .limit(batchSize)
      .get();

    // Combine all videos that need processing
    const videosToAnalyze = [
      ...snapshot.docs,
      ...failedSnapshot.docs,
      ...malformedSnapshot.docs
    ].slice(0, batchSize); // Ensure we don't exceed batch size

    console.log(`Found videos requiring analysis:
      - ${snapshot.size} missing analysis
      - ${failedSnapshot.size} failed analysis
      - ${malformedSnapshot.size} malformed/incomplete analysis
      Total to process: ${videosToAnalyze.length}`);

    const secrets = {
      geminiApiKey: geminiApiKey.value(),
      openaiApiKey: openaiApiKey.value(),
      pineconeApiKey: pineconeApiKey.value(),
      pineconeIndex: pineconeIndex.value(),
    };

    const tasks = videosToAnalyze.map(async (doc) => {
      const video = doc.data() as VideoData;
      try {
        await performVideoAnalysis(doc.ref, video, secrets);
        return { 
          id: doc.id, 
          success: true,
          previousStatus: video.analysis?.status || 'missing' 
        };
      } catch (error) {
        return { 
          id: doc.id, 
          success: false, 
          previousStatus: video.analysis?.status || 'missing',
          error: error instanceof Error ? error.message : 'Unknown error' 
        };
      }
    });

    const results = await Promise.all(tasks);
    res.json({
      summary: {
        total_checked: snapshot.size + failedSnapshot.size + malformedSnapshot.size,
        missing_analysis: snapshot.size,
        failed_analysis: failedSnapshot.size,
        malformed_analysis: malformedSnapshot.size,
        processed: videosToAnalyze.length
      },
      results
    });

  } catch (error) {
    console.error('Error in batchAnalyzeVideos:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Add a new function for finding similar videos
export const findSimilarVideos = functions.https.onCall({
  secrets: [geminiApiKey, openaiApiKey, pineconeApiKey, pineconeIndex]
}, async (request: CallableRequest) => {
  const { videoId, type = 'content', limit = 10 } = request.data as {
    videoId: string;
    type?: 'content' | 'visual' | 'mood';
    limit?: number;
  };

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  try {
    const pineconeClient = new Pinecone({
      apiKey: pineconeApiKey.value(),
    });

    const index = pineconeClient.index(pineconeIndex.value());

    // First, get the vector for the target video
    const targetVector = await index.fetch([`${videoId}_${type}`]);
    if (!targetVector.records[`${videoId}_${type}`]) {
      throw new functions.https.HttpsError('failed-precondition', 'Video embeddings not found');
    }

    // Query Pinecone for similar videos
    const queryResponse = await index.query({
      vector: targetVector.records[`${videoId}_${type}`].values,
      filter: {
        type: type
      },
      topK: limit,
      includeMetadata: true,
    });

    // Get unique video IDs from results
    const similarVideoIds = [...new Set(
      queryResponse.matches
        .map(match => (match.metadata as PineconeMetadata)?.videoId)
        .filter((id): id is string => id !== undefined && id !== videoId)
    )];

    // Fetch video details from Firestore
    const videoDocs = await Promise.all(
      similarVideoIds.map(id => 
        admin.firestore().collection('videos').doc(id).get()
      )
    );

    return {
      videos: videoDocs
        .filter(doc => doc.exists)
        .map(doc => ({
          id: doc.id,
          ...doc.data(),
        })),
    };
  } catch (error) {
    console.error('[ERROR] Error finding similar videos:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to find similar videos'
    );
  }
});

// Update video generation function to use env var
export const generateVideo = functions.https.onCall({
  timeoutSeconds: 540,  // 9 minutes timeout
  memory: '256MiB',
}, async (request: CallableRequest) => {
  console.log('generateVideo: Function started');
  console.log('generateVideo: Request data:', request.data);
  console.log('generateVideo: Auth state:', request.auth ? 'authenticated' : 'not authenticated');

  if (!request.auth) {
    console.log('generateVideo: Authentication check failed');
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { prompt, aspectRatio = '9:16' } = request.data as {
    prompt: string;
    aspectRatio?: string;
  };

  console.log('generateVideo: Extracted parameters:', { prompt, aspectRatio });

  if (!prompt) {
    console.log('generateVideo: Missing prompt');
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  // Get API token from environment variables
  const replicateApiToken = process.env.REPLICATE_API_TOKEN;
  console.log('generateVideo: API token present:', !!replicateApiToken);
  
  if (!replicateApiToken) {
    console.log('generateVideo: No API token found in environment');
    throw new functions.https.HttpsError('failed-precondition', 'Replicate API token not configured');
  }

  try {
    console.log('generateVideo: Starting video generation with Replicate...');
    
    // Initialize Replicate with the API token exactly as in the working example
    const replicate = new Replicate({
      auth: replicateApiToken,
    });

    console.log('generateVideo: Successfully initialized Replicate client');

    // Make the API call using run method exactly as in the working example
    console.log('generateVideo: About to call Replicate API with input:', { prompt, aspectRatio });
    try {
      const input = {
        prompt: prompt,
        aspect_ratio: aspectRatio
      };

      console.log("Generating video with Replicate...");
      const output = await replicate.run("luma/ray", { input });
      console.log("Received URL:", output);

      if (!output) {
        throw new functions.https.HttpsError('internal', 'No output received from video generation');
      }

      return { videoUrl: output };

    } catch (replicateError) {
      console.error('generateVideo: Replicate API error:', replicateError);
      throw new functions.https.HttpsError('internal', `Replicate API error: ${replicateError instanceof Error ? replicateError.message : JSON.stringify(replicateError)}`);
    }

  } catch (error) {
    console.error('generateVideo: Error occurred:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate video');
  }
}); 