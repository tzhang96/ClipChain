const admin = require('firebase-admin');
const functionsTest = require('firebase-functions-test');
const fs = require('fs');
const dotenv = require('dotenv');
const path = require('path');

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

// Log environment variables (without exposing full keys)
console.log('Environment variables loaded:');
console.log('GEMINI_API_KEY:', envConfig.GEMINI_API_KEY ? `${envConfig.GEMINI_API_KEY.slice(0, 5)}...` : 'not set');
console.log('OPENAI_API_KEY:', envConfig.OPENAI_API_KEY ? `${envConfig.OPENAI_API_KEY.slice(0, 5)}...` : 'not set');
console.log('PINECONE_API_KEY:', envConfig.PINECONE_API_KEY ? `${envConfig.PINECONE_API_KEY.slice(0, 5)}...` : 'not set');
console.log('PINECONE_INDEX:', envConfig.PINECONE_INDEX || 'not set');

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

// Mock the parameter values
test.mockParam('GEMINI_API_KEY', envConfig.GEMINI_API_KEY);
test.mockParam('OPENAI_API_KEY', envConfig.OPENAI_API_KEY);
test.mockParam('PINECONE_API_KEY', envConfig.PINECONE_API_KEY);
test.mockParam('PINECONE_INDEX', envConfig.PINECONE_INDEX);

// Timeout duration in milliseconds (5 minutes)
const TIMEOUT_DURATION = 5 * 60 * 1000;

async function testReanalyze() {
  try {
    console.log('=== Starting reanalysis test ===');

    // First, let's get a video document to test with
    console.log('Querying Firestore for videos...');
    const videoSnapshot = await admin.firestore()
      .collection('videos')
      .limit(1)
      .get();

    if (videoSnapshot.empty) {
      console.error('No videos found to test with');
      return;
    }

    const videoDoc = videoSnapshot.docs[0];
    const videoData = videoDoc.data();
    console.log(`Found video document with ID: ${videoDoc.id}`);
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

console.log('Starting reanalysis test...');
testReanalyze(); 