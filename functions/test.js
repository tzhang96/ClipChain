const admin = require('firebase-admin');
const functionsTest = require('firebase-functions-test');
const fs = require('fs');
const dotenv = require('dotenv');
const path = require('path');
const fetch = require('node-fetch');

// Load environment variables
const envConfig = dotenv.config().parsed;

if (!envConfig) {
  console.error('Failed to load .env file');
  process.exit(1);
}

// Set environment variables manually
process.env.GEMINI_API_KEY = envConfig.GEMINI_API_KEY;
process.env.OPENAI_API_KEY = envConfig.OPENAI_API_KEY;
process.env.PINECONE_API_KEY = envConfig.PINECONE_API_KEY;
process.env.PINECONE_INDEX = envConfig.PINECONE_INDEX;
process.env.REPLICATE_API_TOKEN = envConfig.REPLICATE_API_TOKEN;

// Log environment variables (without exposing full keys)
console.log('Environment variables loaded:');
console.log('GEMINI_API_KEY:', envConfig.GEMINI_API_KEY ? `...${envConfig.GEMINI_API_KEY.slice(-10)}` : 'not set');
console.log('OPENAI_API_KEY:', envConfig.OPENAI_API_KEY ? `${envConfig.OPENAI_API_KEY.slice(0, 5)}...` : 'not set');
console.log('PINECONE_API_KEY:', envConfig.PINECONE_API_KEY ? `${envConfig.PINECONE_API_KEY.slice(0, 5)}...` : 'not set');
console.log('PINECONE_INDEX:', envConfig.PINECONE_INDEX || 'not set');
console.log('REPLICATE_API_TOKEN:', envConfig.REPLICATE_API_TOKEN ? `${envConfig.REPLICATE_API_TOKEN.slice(0, 5)}...` : 'not set');

// Check if service account file exists
const SERVICE_ACCOUNT_PATH = './service-account.json';

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`Error: ${SERVICE_ACCOUNT_PATH} not found. Please ensure you have the Firebase service account file in the functions directory.`);
  process.exit(1);
}

// Load service account
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
console.log('Project ID:', serviceAccount.project_id);

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  console.log('Initializing Firebase Admin...');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id
  });
  console.log('Firebase Admin initialized');
}

// Initialize the test SDK with Firebase credentials
const test = functionsTest({
  projectId: serviceAccount.project_id,
}, SERVICE_ACCOUNT_PATH);

// Timeout duration in milliseconds (5 minutes)
const TIMEOUT_DURATION = 5 * 60 * 1000;

async function testReanalyze() {
  try {
    console.log('=== Starting reanalysis test ===');

    // Use the specific video ID
    const videoId = 'Wy6eLgrE3lma7mkPrkbo';
    console.log(`Testing with specific video ID: ${videoId}`);

    // Get the video document
    const videoDoc = await admin.firestore()
      .collection('videos')
      .doc(videoId)
      .get();

    if (!videoDoc.exists) {
      console.error('Video document not found');
      return;
    }

    const videoData = videoDoc.data();
    console.log('Video data:', JSON.stringify(videoData, null, 2));

    // Create a promise that resolves when analysis completes or rejects on timeout
    const analysisPromise = new Promise((resolve, reject) => {
      // Set up document listener
      const unsubscribe = videoDoc.ref.onSnapshot((doc) => {
        const data = doc.data();
        const status = data.analysis?.status || 'unknown';
        const timestamp = new Date().toISOString();
        
        console.log(`[${timestamp}] Status update: ${status}`);
        
        if (data.analysis?.error) {
          console.log('Error details:', data.analysis.error);
        }
        
        if (status === 'completed') {
          console.log('\n=== Analysis completed successfully ===');
          console.log('Final analysis data:', JSON.stringify(data.analysis, null, 2));
          console.log('\nEmbedding status:', data.analysis.hasEmbeddings ? 'Generated' : 'Not generated');
          if (data.analysis.hasEmbeddings) {
            console.log('Embeddings have been generated and stored in Pinecone');
            console.log('You can verify the embeddings in Pinecone by checking these IDs:');
            console.log(`- ${videoDoc.id}_content (Content embedding)`);
            console.log(`- ${videoDoc.id}_visual (Visual embedding)`);
            console.log(`- ${videoDoc.id}_mood (Mood embedding)`);
          }
          unsubscribe();
          resolve(data.analysis);
        } else if (status === 'failed') {
          console.log('\n=== Analysis failed ===');
          console.log('Error details:', data.analysis?.error);
          unsubscribe();
          reject(new Error(data.analysis?.error || 'Analysis failed'));
        }
      });

      // Set up timeout
      setTimeout(() => {
        unsubscribe();
        reject(new Error(`Analysis timed out after ${TIMEOUT_DURATION}ms`));
      }, TIMEOUT_DURATION);
    });

    // Call the reanalyzeVideo function
    console.log('\n=== Triggering reanalysis via Cloud Function ===');
    
    // Wrap the function
    const wrapped = test.wrap(require('./lib/index').reanalyzeVideo);
    
    // Call the function with data and callable context
    try {
      const result = await wrapped({
        data: { videoId: videoDoc.id },
        auth: {
          uid: videoData.userId,
          token: {
            firebase: {
              sign_in_provider: 'custom'
            }
          }
        }
      });
      console.log('Function call successful, result:', result);
    } catch (funcError) {
      console.error('Function call failed:', funcError);
      throw funcError;
    }
    
    console.log('Reanalysis triggered, waiting for completion...\n');

    // Wait for analysis to complete or timeout
    await analysisPromise;
    
    console.log('\n=== Test completed successfully ===');
    process.exit(0);

  } catch (error) {
    console.error('\n=== Test failed with error ===');
    console.error('Error:', error.message);
    process.exit(1);
  } finally {
    // Clean up
    test.cleanup();
  }
}

async function testBatchAnalyze() {
  try {
    console.log('=== Starting batch analysis test ===');
    
    // Get the function URL from environment or use the emulator URL
    const functionUrl = process.env.FUNCTION_URL || 'http://127.0.0.1:5001/reelai-de1cb/us-central1/batchAnalyzeVideos';
    
    console.log('\n=== Triggering batch analysis ===');
    console.log('Function URL:', functionUrl);
    
    const response = await fetch(functionUrl);
    console.log('Response status:', response.status);
    
    const responseText = await response.text();
    console.log('\nRaw response:', responseText);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}, body: ${responseText}`);
    }
    
    let responseData;
    try {
      responseData = JSON.parse(responseText);
    } catch (e) {
      throw new Error(`Failed to parse JSON response: ${e.message}\nRaw response: ${responseText}`);
    }
    
    if (responseData) {
      console.log('\n=== Batch Analysis Summary ===');
      if (responseData.summary) {
        console.log(`Total videos checked: ${responseData.summary.total_checked}`);
        console.log(`Videos missing analysis: ${responseData.summary.missing_analysis}`);
        console.log(`Videos with failed analysis: ${responseData.summary.failed_analysis}`);
        console.log(`Videos with malformed analysis: ${responseData.summary.malformed_analysis}`);
        console.log(`Videos processed: ${responseData.summary.processed}`);
      } else {
        console.log('No summary data in response');
      }
      
      if (responseData.results && responseData.results.length > 0) {
        console.log('\nProcessing Results:');
        responseData.results.forEach((result, index) => {
          console.log(`\nVideo ${index + 1}:`);
          console.log(`- ID: ${result.id}`);
          console.log(`- Success: ${result.success}`);
          console.log(`- Previous Status: ${result.previousStatus}`);
          if (result.error) {
            console.log(`- Error: ${result.error}`);
          }
        });
      } else {
        console.log('\nNo results data in response');
      }
    }

    console.log('\n=== Test completed successfully ===');
    process.exit(0);

  } catch (error) {
    console.error('\n=== Test failed with error ===');
    console.error('Error:', error.message);
    process.exit(1);
  } finally {
    // Clean up
    test.cleanup();
  }
}

// Get the test type from command line arguments
const testType = process.argv[2] || 'reanalyze';

console.log(`Starting ${testType} test...`);
if (testType === 'batch') {
  testBatchAnalyze();
} else {
  testReanalyze();
} 